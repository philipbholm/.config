import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


DEV = Path(__file__).resolve().parents[1] / "dev.sh"


class SessionSearchTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.repo = self.root / "ledidi-monorepo"
        self.repo.mkdir()
        subprocess.run(["git", "init", "--quiet", str(self.repo)], check=True)
        self.home = self.root / "home"
        self.env = {**os.environ, "DEV_SESSION_HOME": str(self.home)}

    def write_log(self, path, entries):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(json.dumps(entry) for entry in entries) + "\n")

    def codex(self, name, messages, archived=False, cwd=None, source="cli"):
        directory = "archived_sessions" if archived else "sessions/2026/09/01"
        path = self.home / ".codex" / directory / f"{name}.jsonl"
        self.write_log(path, [{"type": "session_meta", "payload": {
            "id": name, "cwd": str(cwd or self.repo), "source": source,
            "git": {"branch": "feature"}}}, *messages])
        return path

    def response(self, text, day="2026-09-01"):
        return {"type": "response_item", "timestamp": day + "T10:00:00Z", "payload": {
            "type": "message", "role": "user", "content": [{"type": "input_text", "text": text}]}}

    def event(self, text):
        return {"type": "event_msg", "timestamp": "2026-09-01T10:00:00Z",
                "payload": {"type": "user_message", "message": text}}

    def claude(self, name, texts, side=False):
        folder = str(self.repo).replace("/", "-")
        path = self.home / ".claude/projects" / folder / f"{name}.jsonl"
        self.write_log(path, [{"type": "user", "cwd": str(self.repo), "sessionId": name,
                              "gitBranch": "feature", "uuid": f"{name}-{i}", "isSidechain": side,
                              "timestamp": "2026-09-01T10:00:00Z", "message": {"content": text}}
                             for i, text in enumerate(texts)])
        return path

    def search(self, *args):
        result = subprocess.run(["bash", str(DEV), "session", "search", "--repo", str(self.repo),
                                 "--json", *args], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_read_both_codex_formats_once_per_turn(self):
        self.codex("paired", [self.event("Repeat this check"), self.response("Repeat this check"),
                              self.event("Repeat this check"), self.response("Repeat this check")])
        self.codex("event-only", [self.event("An older conversation")])
        self.codex("response-only", [self.response("A newer conversation")])
        self.assertEqual(self.search()["total"], 4)

    def test_exclude_other_repositories_subagents_and_injected_context(self):
        self.codex("other", [self.response("Secret other repo")], cwd=self.root / "ledidi-monorepo-other")
        self.codex("agent", [self.response("Delegated prompt")], source={"subagent": "review"})
        self.claude("side", ["Another delegated prompt"], side=True)
        self.codex("main", [self.response("# AGENTS.md instructions for this repo"),
                            self.response("<skill>injected instructions</skill>"), self.response("Actual request")])
        result = self.search()
        self.assertEqual(result["total"], 1)
        self.assertEqual(result["matches"][0]["excerpt"], "Actual request")

    def test_keep_archives_and_removed_codex_worktrees(self):
        path = self.codex("archived", [self.response("Recover the old map")], archived=True,
                          cwd=self.home / ".codex/worktrees/abcd/ledidi-monorepo")
        result = self.search("old map")
        self.assertEqual(result["total"], 1)
        self.assertEqual(result["matches"][0]["path"], str(path))

    def test_deduplicate_cross_harness_copies_not_independent_short_replies(self):
        self.claude("original", ["Discuss ticket 42", "Agree"])
        self.codex("copy", [self.response("Discuss ticket 42"), self.response("Agree")])
        self.claude("another", ["Agree"])
        self.claude("separate", ["Agree"])
        self.assertEqual(self.search()["total"], 4)

    def test_filter_branch_ticket_dates_and_harness(self):
        self.codex("dates", [self.response("Review ticket 42", "2026-09-01"),
                             self.response("Review ticket 420", "2026-09-02"),
                             self.response("Review ticket 42", "2026-09-03")])
        result = self.search("Review", "--ticket", "42", "--since", "2026-09-02", "--until", "2026-09-03",
                             "--branch", "feature", "--harness", "codex")
        self.assertEqual(result["total"], 1)
        self.assertTrue(result["matches"][0]["date"].startswith("2026-09-03"))
        self.assertEqual(self.search("--branch", "unknown")["total"], 0)

    def test_report_original_import_date_and_skip_partial_trailing_line(self):
        path = self.codex("import", [{"type": "event_msg", "payload": {"type": "task_started",
                          "turn_id": "external-import-turn-1", "started_at": 1788228000}},
                                    self.response("Find the imported ticket")])
        with path.open("a") as stream:
            stream.write('{"partial":')
        before = path.read_bytes()
        result = self.search("imported", "--until", "2026-09-01")
        self.assertEqual(result["total"], 1)
        self.assertTrue(result["matches"][0]["date"].startswith("2026-09-01"))
        self.assertEqual(path.read_bytes(), before)

    def test_reject_invalid_filters(self):
        for args in [["--since", "invalid"], ["--limit", "0"], ["--since", "2026-09-02", "--until", "2026-09-01"]]:
            result = subprocess.run(["bash", str(DEV), "session", "search", *args],
                                    env=self.env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)


if __name__ == "__main__":
    unittest.main()
