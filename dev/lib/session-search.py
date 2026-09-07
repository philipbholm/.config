"""Search local user messages without loading tool output or assistant prompts."""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from collections import Counter
from datetime import date, datetime, timezone
from pathlib import Path


def records(path):
    try:
        with path.open() as stream:
            for line, value in enumerate(stream, 1):
                try:
                    record = json.loads(value)
                    if isinstance(record, dict):
                        yield line, record
                except (ValueError, UnicodeError):
                    continue
    except (OSError, UnicodeError) as error:
        print(f"Cannot read {path}: {error}", file=sys.stderr)


def message_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(part.get("text", "") for part in content
                         if isinstance(part, dict) and part.get("type") in
                         {"text", "input_text"})
    return ""


def user_text(text):
    stripped = text.lstrip()
    if stripped.startswith(("# AGENTS.md instructions", "<environment_context>",
                            "<INSTRUCTIONS>", "<skill>", "<recommended_plugins>",
                            "<task-notification>", "<teammate-message",
                            "Another Claude session sent", "<local-command",
                            "<command-name>/clear", "<command-name>/compact",
                            "<bash-stdout>", "[Request interrupted",
                            "<turn_aborted>", "This session is being continued")):
        return ""
    return text.strip()


def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True,
                            text=True, check=True)
    return result.stdout.strip()


def repository_paths(repo):
    common = Path(git(repo, "rev-parse", "--git-common-dir"))
    main = (repo / common).resolve().parent
    paths = [Path(line[9:]).resolve() for line in
             git(repo, "worktree", "list", "--porcelain").splitlines()
             if line.startswith("worktree ")]
    return main, paths


def belongs(cwd, main, worktrees, home):
    if not cwd:
        return False
    path = Path(cwd).expanduser().resolve()
    if any(path == root or root in path.parents for root in [main, *worktrees]):
        return True
    # Removed Codex worktrees no longer appear in Git's worktree registry.
    codex_root = home / ".codex/worktrees"
    try:
        relative = path.relative_to(codex_root)
        return len(relative.parts) >= 2 and relative.parts[1] == main.name
    except ValueError:
        return False


def make_message(harness, path, line, record, text, cwd, branch, session):
    return {"harness": harness, "session_id": session, "date": record.get("timestamp", ""),
            "cwd": cwd, "branch": branch or "", "path": str(path), "line": line,
            "text": text}


def claude_messages(path, matches_repo):
    messages = []
    seen = set()
    for line, record in records(path):
        if (record.get("type") != "user" or record.get("isSidechain") or
                record.get("isMeta") or record.get("isCompactSummary") or
                not matches_repo(record.get("cwd", ""))):
            continue
        message = record.get("message", {})
        if not isinstance(message, dict):
            continue
        text = user_text(message_text(message.get("content", "")))
        identity = record.get("uuid", line)
        if text and identity not in seen:
            seen.add(identity)
            messages.append(make_message("claude", path, line, record, text,
                                        record["cwd"], record.get("gitBranch"),
                                        record.get("sessionId", path.stem)))
    return messages


def codex_messages(path, matches_repo):
    stream = records(path)
    _, first = next(stream, (0, {}))
    meta = first.get("payload", {})
    if not isinstance(meta, dict):
        return []
    if (first.get("type") != "session_meta" or
            isinstance(meta.get("source"), dict) and "subagent" in meta["source"] or
            not matches_repo(meta.get("cwd", ""))):
        return []
    cwd = meta["cwd"]
    branch = meta.get("git", {}).get("branch", "")
    session = meta.get("id", meta.get("session_id", path.stem))
    events, responses = [], []
    original_time = ""
    for line, record in stream:
        payload = record.get("payload", {})
        if not isinstance(payload, dict):
            continue
        kind = record.get("type")
        if kind == "turn_context":
            next_cwd = payload.get("cwd", cwd)
            if next_cwd != cwd:
                branch = ""
            cwd = next_cwd
        if kind == "event_msg" and payload.get("type") == "task_started":
            started = payload.get("started_at")
            if str(payload.get("turn_id", "")).startswith("external-import-") and isinstance(started, (int, float)):
                original_time = datetime.fromtimestamp(started, timezone.utc).isoformat()
        text = ""
        target = responses
        if kind == "response_item" and payload.get("type") == "message" and payload.get("role") == "user":
            text = user_text(message_text(payload.get("content")))
        elif kind == "event_msg" and payload.get("type") == "user_message":
            text = user_text(payload.get("message", ""))
            target = events
        if text and matches_repo(cwd):
            message = make_message("codex", path, line, record, text, cwd, branch, session)
            if original_time:
                message["date"] = original_time
            target.append(message)
    # Older logs emit both forms for each user turn; newer logs may emit only one.
    response_counts = Counter(message["text"] for message in responses)
    for message in events:
        if response_counts[message["text"]]:
            response_counts[message["text"]] -= 1
        else:
            responses.append(message)
    return sorted(responses, key=lambda message: message["line"])


def sessions(home, main, worktrees, harness):
    matches_repo = lambda cwd: belongs(cwd, main, worktrees, home)
    if harness in {"all", "claude"}:
        projects = home / ".claude/projects"
        roots = [main, *worktrees]
        encoded = [re.sub(r"[^a-zA-Z0-9]", "-", str(root)) for root in roots]
        if projects.is_dir():
            for directory in sorted(projects.iterdir()):
                if not directory.is_dir():
                    continue
                codex_prefix = re.sub(r"[^a-zA-Z0-9]", "-", str(home / ".codex/worktrees")) + "-"
                old_codex = directory.name.startswith(codex_prefix) and directory.name.endswith("-" + main.name)
                if not old_codex and not any(directory.name == key or directory.name.startswith(key + "-") for key in encoded):
                    continue
                for path in sorted(directory.glob("*.jsonl")):
                    yield claude_messages(path, matches_repo)
    if harness in {"all", "codex"}:
        for directory in [home / ".codex/sessions", home / ".codex/archived_sessions"]:
            for path in sorted(directory.rglob("*.jsonl")):
                yield codex_messages(path, matches_repo)


def search(args):
    home = Path(os.environ.get("DEV_SESSION_HOME", Path.home())).resolve()
    main, worktrees = repository_paths(args.repo)
    groups = []
    fingerprints = {}
    for messages in sessions(home, main, worktrees, args.harness):
        if not messages:
            continue
        fingerprint = hashlib.sha256(json.dumps([" ".join(m["text"].split()) for m in messages]).encode()).hexdigest()
        # Compare complete conversations; identical short replies in different
        # conversations must remain separate matches.
        previous = fingerprints.setdefault(fingerprint, [])
        if any(prior["harness"] != messages[0]["harness"] or
               prior["session_id"] == messages[0]["session_id"] for prior in previous):
            continue
        previous.append(messages[0])
        groups.extend(messages)
    found = []
    for message in groups:
        text = message["text"]
        day = message["date"][:10]
        if args.branch and message["branch"] != args.branch:
            continue
        if (args.since and day < args.since.isoformat()) or (args.until and day > args.until.isoformat()):
            continue
        if args.ticket and not re.search(r"(?<!\w)" + re.escape(args.ticket) + r"(?!\w)", text, re.I):
            continue
        if args.text and args.text.casefold() not in text.casefold():
            continue
        compact = " ".join(text.split())
        position = compact.casefold().find(args.text.casefold()) if args.text else 0
        start = max(0, position - 80)
        excerpt = ("…" if start else "") + compact[start:start + 320]
        message = {key: value for key, value in message.items() if key != "text"}
        message["excerpt"] = excerpt
        found.append(message)
    found.sort(key=lambda message: message["date"], reverse=True)
    return found


def positive_integer(value):
    result = int(value)
    if result < 1:
        raise argparse.ArgumentTypeError("must be positive")
    return result


def main():
    parser = argparse.ArgumentParser(prog="dev session search", description=
        "Search local user messages for one repository. No network access or transcript writes.")
    parser.add_argument("text", nargs="?", default="", help="literal text to find")
    parser.add_argument("--repo", type=Path, default=Path.cwd(), help="repository or worktree path (default: current repository)")
    parser.add_argument("--branch", help="exact recorded Git branch; messages without branch metadata are excluded")
    parser.add_argument("--ticket", help="ticket number or slug appearing in the user message")
    parser.add_argument("--since", type=date.fromisoformat, help="inclusive YYYY-MM-DD")
    parser.add_argument("--until", type=date.fromisoformat, help="inclusive YYYY-MM-DD")
    parser.add_argument("--harness", choices=["all", "claude", "codex"], default="all")
    parser.add_argument("--limit", type=positive_integer, default=20)
    parser.add_argument("--json", action="store_true", help="return matches and total as JSON")
    args = parser.parse_args()
    if args.since and args.until and args.since > args.until:
        parser.error("--since must not be after --until")
    try:
        found = search(args)
    except (subprocess.CalledProcessError, OSError) as error:
        parser.exit(2, f"Cannot resolve repository {args.repo}: {error}\n")
    shown = found[:args.limit]
    if args.json:
        print(json.dumps({"total": len(found), "matches": shown}, ensure_ascii=False, indent=2))
    else:
        print(f"{len(found)} matching user messages; showing {len(shown)}.")
        for message in shown:
            print(f"\n{message['date']} {message['harness']} {message['session_id']}")
            print(f"Checkout: {message['cwd']}  Branch: {message['branch'] or 'not recorded'}")
            print(f"{message['path']}:{message['line']}\n{message['excerpt']}")


if __name__ == "__main__":
    main()
