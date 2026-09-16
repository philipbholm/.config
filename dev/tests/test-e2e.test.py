import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


DEV = Path(__file__).resolve().parents[1]


class E2ETest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repo = self.root / "repo"
        self.repo.mkdir()
        subprocess.run(["git", "init", "-q", str(self.repo)], check=True)
        self.dev = self.root / "dev"
        self.dev.mkdir()
        shutil.copytree(DEV / "lib", self.dev / "lib")
        for name in ["dev.sh", "test-e2e.sh"]:
            shutil.copy(DEV / name, self.dev / name)
        self.workspace = self.repo / "apps/registries-frontend"
        self.workspace.mkdir(parents=True)
        for name in ["playwright.config.ts", "playwright.shell.config.ts"]:
            (self.workspace / name).touch()
        (self.dev / "stack.sh").write_text('''#!/bin/bash
set -euo pipefail
echo "$*" > "$TEST_STACK_CALL"
[[ "${TEST_STACK_FAIL:-0}" == 0 ]] || exit 9
mkdir -p "$DEV_STACKS_DIR/feature"
echo 6 > "$DEV_STACKS_DIR/feature/worktree-slot"
''')
        (self.dev / "lib/e2e-preflight.py").write_text('''import os, sys
sys.exit(int(os.environ.get("TEST_PREFLIGHT_FAIL", "0")))
''')
        self.bin = self.root / "bin"
        self.bin.mkdir()
        npm = self.bin / "npm"
        npm.write_text(f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
Path(os.environ["TEST_NPM_CALL"]).write_text(json.dumps({
    "args": sys.argv[1:], "cwd": os.getcwd(),
    "urls": {name: os.environ[name] for name in ["E2E_API_URL", "VITE_REGISTRIES_API_URL", "FRONTEND_BASE_URL", "REGISTRIES_BASE_URL"]}
}))
sys.exit(int(os.environ.get("TEST_NPM_EXIT", "0")))
''')
        npm.chmod(0o755)
        self.env = {**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}",
                    "DEV_STACKS_DIR": str(self.root / "stacks"),
                    "TEST_STACK_CALL": str(self.root / "stack-call"),
                    "TEST_NPM_CALL": str(self.root / "npm-call"),
                    "E2E_API_URL": "http://localhost:4006/graphql",
                    "VITE_REGISTRIES_API_URL": "http://localhost:4006"}

    def run_e2e(self, *args, cwd=None):
        return subprocess.run(["bash", str(self.dev / "dev.sh"), "test", "e2e", *args],
                              cwd=cwd or self.repo, env=self.env, capture_output=True, text=True)

    def test_pass_slot_six_to_both_browser_and_fixtures_after_startup(self):
        subprocess.run(["git", "-C", str(self.repo), "-c", "user.name=Test",
                        "-c", "user.email=test@example.invalid", "-c", "commit.gpgsign=false",
                        "-c", "core.hooksPath=/dev/null", "commit", "--allow-empty", "-qm", "Fixture"], check=True)
        worktree = self.root / "feature"
        subprocess.run(["git", "-C", str(self.repo), "worktree", "add", "-qb", "feature", str(worktree)], check=True)
        shutil.copytree(self.repo / "apps", worktree / "apps")
        result = self.run_e2e("--shell", "--", "dashboard/my test.spec.tsx", "--workers=1", cwd=worktree)
        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads((self.root / "npm-call").read_text())
        self.assertEqual(recorded["urls"], {
            "E2E_API_URL": "http://localhost:4606/graphql",
            "VITE_REGISTRIES_API_URL": "http://localhost:4606",
            "FRONTEND_BASE_URL": "http://localhost:3610",
            "REGISTRIES_BASE_URL": "http://localhost:3604",
        })
        self.assertEqual(recorded["args"], ["run", "test:e2e:shell", "--", "dashboard/my test.spec.tsx", "--workers=1"])
        self.assertEqual(Path(recorded["cwd"]).resolve(), (worktree / "apps/registries-frontend").resolve())
        self.assertEqual((self.root / "stack-call").read_text().strip(), "up registries codelist -d")

    def test_use_main_ports_and_propagate_the_test_exit_code(self):
        self.env["TEST_NPM_EXIT"] = "7"
        result = self.run_e2e("--", "--project=chromium")
        self.assertEqual(result.returncode, 7, result.stderr)
        recorded = json.loads((self.root / "npm-call").read_text())
        self.assertEqual(recorded["urls"]["E2E_API_URL"], "http://localhost:4006/graphql")
        self.assertEqual(recorded["urls"]["FRONTEND_BASE_URL"], "http://localhost:3004")
        self.assertEqual(recorded["args"], ["run", "test:e2e", "--", "--project=chromium"])

    def test_stop_before_npm_when_startup_or_readiness_fails(self):
        for variable in ["TEST_STACK_FAIL", "TEST_PREFLIGHT_FAIL"]:
            self.env[variable] = "1"
            self.assertNotEqual(self.run_e2e().returncode, 0)
            self.assertFalse((self.root / "npm-call").exists())
            del self.env[variable]

    def test_probe_graphql_and_reject_an_occupied_preview_port(self):
        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                self.server.query = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps(self.server.result).encode())

            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        server.result = {"data": {"__typename": "Query"}}
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            preview_port = listener.getsockname()[1]
        env = {**os.environ, "E2E_API_URL": f"http://127.0.0.1:{server.server_port}/graphql",
               "FRONTEND_BASE_URL": f"http://127.0.0.1:{preview_port}",
               "REGISTRIES_BASE_URL": f"http://127.0.0.1:{preview_port}"}

        def preflight():
            return subprocess.run([sys.executable, str(DEV / "lib/e2e-preflight.py")],
                                  env=env, capture_output=True, text=True)

        self.assertEqual(preflight().returncode, 0)
        self.assertEqual(server.query, {"query": "{ __typename }"})
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", preview_port))
            result = preflight()
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("occupied", result.stderr)
        server.result = {"errors": [{"message": "Backend is broken"}]}
        result = preflight()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not ready", result.stderr)


if __name__ == "__main__":
    unittest.main()
