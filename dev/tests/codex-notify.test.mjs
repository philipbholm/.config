import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const script = fileURLToPath(new URL("../codex-notify.sh", import.meta.url));
const parentId = "00000000-0000-4000-8000-000000000001";
const childId = "00000000-0000-4000-8000-000000000002";

function fixture(t, { customHome = false } = {}) {
  const directory = mkdtempSync(join(tmpdir(), "codex-notify-test-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const bin = join(directory, "bin");
  const codexHome = join(directory, customHome ? "custom codex home" : ".codex");
  const sessions = join(codexHome, "sessions", "2026", "09", "20");
  mkdirSync(bin);
  mkdirSync(sessions, { recursive: true });
  const calls = join(directory, "calls");
  writeFileSync(calls, "");
  for (const command of ["terminal-notifier", "osascript"]) {
    writeFileSync(join(bin, command), '#!/bin/bash\nprintf "sent\\n" >> "$NOTIFY_TEST_CALLS"\n', { mode: 0o755 });
  }
  const env = {
    ...process.env,
    HOME: directory,
    PATH: `${bin}:${process.env.PATH}`,
    CODEX_NOTIFY_LOG: join(directory, "notify.log"),
    NOTIFY_TEST_CALLS: calls,
  };
  delete env.CODEX_HOME;
  if (customHome) env.CODEX_HOME = codexHome;
  return {
    session(id, source) {
      writeFileSync(join(sessions, `rollout-2026-09-20T08-00-00-${id}.jsonl`),
        JSON.stringify({ type: "session_meta", payload: { id, source } }) + "\n");
    },
    notify(id) {
      const result = spawnSync("bash", [script, JSON.stringify({
        type: "agent-turn-complete", "thread-id": id, "turn-id": "turn", cwd: "/tmp/project",
      })], { env, encoding: "utf8", timeout: 10000 });
      assert.equal(result.status, 0, result.stderr);
    },
    calls: () => readFileSync(calls, "utf8"),
  };
}

test("Notify when the main agent finishes, but not when its child finishes", (t) => {
  const f = fixture(t);
  f.session(parentId, "cli");
  f.session(childId, { subagent: { thread_spawn: { parent_thread_id: parentId, depth: 1 } } });

  f.notify(childId);
  assert.equal(f.calls(), "");
  f.notify(parentId);
  assert.equal(f.calls(), "sent\n");
});

test("Find child-agent metadata under CODEX_HOME", (t) => {
  const f = fixture(t, { customHome: true });
  f.session(childId, { subagent: { thread_spawn: { parent_thread_id: parentId, depth: 2 } } });

  f.notify(childId);
  assert.equal(f.calls(), "");
});

test("Keep notifications when session metadata is unavailable", (t) => {
  const f = fixture(t);

  f.notify(parentId);
  assert.equal(f.calls(), "sent\n");
});
