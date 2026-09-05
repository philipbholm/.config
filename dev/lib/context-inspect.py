"""Inspect shared instruction wiring without loading credentials or changing it."""

import argparse
import json
import os
import re
import subprocess
from pathlib import Path


def command(*args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout.strip()


def resolved_file(path):
    try:
        return {"path": str(path), "resolved": str(path.resolve()), "exists": path.is_file()}
    except (OSError, RuntimeError):
        return {"path": str(path), "resolved": "unresolvable symlink", "exists": False}


def inspect(config, home):
    checkout = Path(command("git", "rev-parse", "--show-toplevel")).resolve()
    common = Path(command("git", "rev-parse", "--git-common-dir"))
    main = (Path.cwd() / common).resolve().parent
    branch = command("git", "branch", "--show-current") or "detached HEAD"
    slot_file = Path(command("bash", "-c", '. "$1"; dev_slot_file_for_repo "$2"',
                             "context-inspect", str(config / "dev/lib/checkout.sh"), str(checkout)))
    ledidi = main == Path(os.environ.get("DEV_MAIN_REPO", Path.home() / "work/ledidi-monorepo")).resolve()
    slot = "not a Ledidi checkout"
    if ledidi:
        slot = "0" if checkout == main else (slot_file.read_text().strip() if slot_file.is_file() else "not assigned")
    instructions = {
        "Claude Code global": home / ".claude/CLAUDE.md",
        "Codex global": home / ".codex/AGENTS.md",
        "Cursor global": home / "AGENTS.md",
        "Checkout AGENTS": checkout / "AGENTS.md",
        "Checkout Claude": checkout / ("CLAUDE.local.md" if ledidi else "CLAUDE.md"),
        "Ledidi template": config / "dev/context/ledidi-monorepo/AGENTS.md",
    }
    skills = {}
    for harness, directory in [("Claude Code", home / ".claude/skills"),
                               ("Codex and Cursor", home / ".agents/skills")]:
        skills[harness] = {entry.name: resolved_file(entry / "SKILL.md")
                           for entry in sorted(directory.iterdir())
                           if entry.is_dir() or entry.is_symlink()} if directory.is_dir() else {}
    urls = []
    context = checkout / "AGENTS.md"
    if context.is_file():
        urls = re.findall(r"^\| (?:Frontend|Registries \([^)]*\)|Codelist \([^)]*\)|PostgreSQL) \| (.*?) \|$",
                          context.read_text(), re.M)
    return {"checkout": str(checkout), "branch": branch, "main_checkout": str(main),
            "slot": slot, "slot_file": str(slot_file), "rendered_urls": urls,
            "instructions": {name: resolved_file(path) for name, path in instructions.items()},
            "skills": skills}


def problems(report, config):
    failures = []
    for name, entry in report["instructions"].items():
        if not entry["exists"]:
            failures.append(f"Missing or broken {name}: {entry['path']}")
        elif name.endswith("global") and Path(entry["resolved"]) != (config / "agents/AGENTS.md").resolve():
            failures.append(f"Unexpected {name} source: {entry['path']} -> {entry['resolved']}")
    expected = {path.parent.name: path.resolve() for root in ["skills", "skills.work"]
                for path in (config / root).glob("*/SKILL.md")}
    for harness, skills in report["skills"].items():
        for name, source in expected.items():
            entry = skills.get(name)
            if not entry or not entry["exists"]:
                failures.append(f"Missing {harness} skill: {name}")
            elif Path(entry["resolved"]) != source:
                failures.append(f"Unexpected {harness} skill source: {name} -> {entry['resolved']}")
        for name, entry in skills.items():
            if not entry["exists"] and name not in expected:
                failures.append(f"Broken {harness} skill: {entry['path']}")
    template = Path(report["instructions"]["Ledidi template"]["path"])
    if template.is_file():
        for skill in re.findall(r"^\|[^\n]+\| `([a-z0-9-]+)` \|$", template.read_text(), re.M):
            if skill not in expected:
                failures.append(f"Template references missing shared skill: {skill}")
    documents = [template, *expected.values()]
    available = set(expected)
    for skills in report["skills"].values():
        available.update(name for name, entry in skills.items() if entry["exists"])
    for document in documents:
        if not document.is_file():
            continue
        text = document.read_text()
        for skill in re.findall(r"\b[Ll]oad (?:the )?`([a-z0-9-]+)`", text):
            if skill not in available:
                failures.append(f"Missing referenced skill {skill}: {document}")
        for target in re.findall(r"\]\(([^)]+\.md)(?:#[^)]*)?\)", text):
            if "://" not in target and "<" not in target:
                linked = document.parent / target
                if not linked.is_file():
                    failures.append(f"Broken document link: {document} -> {target}")
    return failures


def main():
    parser = argparse.ArgumentParser(prog="dev context")
    parser.add_argument("action", choices=["show", "check"])
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    config = Path(__file__).resolve().parents[2]
    home = Path(os.environ.get("DEV_CONTEXT_HOME", Path.home())).resolve()
    try:
        report = inspect(config, home)
        failures = problems(report, config) if args.action == "check" else []
    except (subprocess.CalledProcessError, OSError) as error:
        parser.exit(2, f"Cannot inspect context: {error}\n")
    if args.json:
        print(json.dumps(report, indent=2))
    elif args.action == "show":
        print(f"Checkout: {report['checkout']}\nBranch: {report['branch']}\nMain checkout: {report['main_checkout']}")
        print(f"Slot: {report['slot']} (saved assignment; not a running-service check)")
        print(f"Slot file: {report['slot_file']}")
        for url in report["rendered_urls"]:
            print(f"Rendered endpoint: {url}")
        for name, entry in report["instructions"].items():
            print(f"{name}: {entry['path']} -> {entry['resolved']}" + (" (missing)" if not entry['exists'] else ""))
        for harness, skills in report["skills"].items():
            print(f"\n{harness} skills:")
            for name, entry in skills.items():
                print(f"  {name}: {entry['resolved']}" + (" (missing)" if not entry['exists'] else ""))
        print("\nShows filesystem wiring; an existing agent session may have loaded an earlier version.")
    else:
        for failure in failures:
            print(failure)
        if not failures:
            print("Shared instruction and skill links are current for Claude Code, Codex, and Cursor.")
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
