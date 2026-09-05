import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const source = fileURLToPath(new URL("..", import.meta.url));
const scripts = ["dev", "stack", "worktree-create", "worktree-destroy", "workspace-prepare",
  "stack-expose", "context-render", "agent-config-apply", "browser-launch-debug"];

function fixture(t) {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), "dev-cli-test-")));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const tools = join(directory, "tools");
  const bin = join(directory, "bin");
  const repo = join(directory, "repo");
  const log = join(directory, "calls.jsonl");
  const effect = join(directory, "env-sourced");
  for (const path of [tools, bin, repo, join(directory, "hooks")]) mkdirSync(path);
  for (const script of scripts) cpSync(join(source, `${script}.sh`), join(tools, `${script}.sh`));
  cpSync(join(source, "lib"), join(tools, "lib"), { recursive: true });
  cpSync(join(source, "context/ledidi-monorepo"), join(tools, "context/ledidi-monorepo"), { recursive: true });
  writeFileSync(join(tools, ".env.local"), 'printf sourced > "$DEV_TEST_EFFECT"\n');
  writeFileSync(log, "");
  for (const command of ["docker", "npm", "cloudflared", "rover", "lsof", "osascript", "terminal-notifier", "npx"]) {
    writeFileSync(join(bin, command), `#!${process.execPath}
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.DEV_TEST_LOG, JSON.stringify({ command: ${JSON.stringify(command)}, args }) + "\\n");
if (${JSON.stringify(command)} !== "docker" || process.env.DEV_TEST_DOCKER !== "allow") process.exit(99);
if (args.includes("--services")) process.stdout.write("postgres\\nregistries\\n");
`, { mode: 0o755 });
  }
  const env = {
    ...process.env,
    PATH: `${bin}:${process.env.PATH}`,
    DEV_MAIN_REPO: repo,
    DEV_STACKS_DIR: join(directory, "stacks"),
    DEV_TEST_LOG: log,
    DEV_TEST_EFFECT: effect,
    GIT_CONFIG_COUNT: "1",
    GIT_CONFIG_KEY_0: "core.hooksPath",
    GIT_CONFIG_VALUE_0: join(directory, "hooks"),
  };
  function git(...args) {
    const result = spawnSync("git", ["-C", repo, ...args], { env, encoding: "utf8" });
    assert.equal(result.status, 0, result.stderr);
    return result.stdout;
  }
  git("init", "--quiet");
  git("-c", "user.name=CLI Test", "-c", "user.email=cli-test@example.invalid", "-c", "commit.gpgsign=false",
    "commit", "--allow-empty", "-m", "Create fixture");
  return {
    directory, tools, bin, repo, env, effect, git,
    run: (args, cwd = directory) => spawnSync("bash", [join(tools, "dev.sh"), ...args], {
      cwd, env, encoding: "utf8", timeout: 10000,
    }),
    calls: () => readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse),
  };
}

const commands = [[], ["worktree"], ["workspace"], ["stack"], ["context"], ["agent-config"], ["browser"],
  ["worktree", "create"], ["worktree", "destroy"], ["workspace", "prepare"],
  ...["up", "down", "destroy", "list", "expose", "logs", "exec", "ps", "build", "stop", "restart"].map(action => ["stack", action]),
  ["context", "render"], ["agent-config", "apply"], ["browser", "launch-debug"]];

for (const args of commands) {
  test(`Show help for dev ${args.join(" ")} without side effects`, (t) => {
    const f = fixture(t);
    const result = f.run([...args, "--help"]);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Usage: dev/);
    assert.deepEqual(f.calls(), []);
    assert.equal(existsSync(f.effect), false);
    assert.equal(existsSync(f.env.DEV_STACKS_DIR), false);
  });
}

for (const args of [["unknown"], ["worktree", "delete"], ["worktree", "destroy", "--force"],
  ["stack", "unknown"], ["stack", "start"], ["stack", "destroy", "--force"], ["stack", "list", "--all"],
  ["stack", "expose", "--unknown"], ["context", "render", "--unknown"],
  ["agent-config", "apply"], ["agent-config", "apply", "--profile", "personal"],
  ["browser", "launch-debug", "--unknown"]]) {
  test(`Reject dev ${args.join(" ")} before side effects`, (t) => {
    const f = fixture(t);
    const result = f.run(args);
    assert.equal(result.status, 2, result.stderr);
    assert.deepEqual(f.calls(), []);
    assert.equal(existsSync(f.effect), false);
  });
}

test("Find help when dev is reached through its installed symlink", (t) => {
  const f = fixture(t);
  const entry = join(f.bin, "dev");
  symlinkSync(join(f.tools, "dev.sh"), entry);
  const result = spawnSync("bash", [entry, "--help"], { cwd: f.directory, env: f.env, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /dev <thing> <action>/);
  assert.deepEqual(f.calls(), []);
});

test("List stacks outside a Git repository without generating stack files", (t) => {
  const f = fixture(t);
  f.env.DEV_TEST_DOCKER = "allow";
  const result = f.run(["stack", "list"]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /No dev stacks running/);
  assert.equal(existsSync(f.env.DEV_STACKS_DIR), false);
  assert.ok(f.calls().every(call => call.command === "docker" && ["info", "ps"].includes(call.args[0])));
});

test("Render only the current checkout unless all worktrees are requested", (t) => {
  const f = fixture(t);
  const worktree = join(f.directory, "worktree");
  f.git("worktree", "add", "-b", "feature", worktree);
  writeFileSync(join(f.repo, "AGENTS.md"), "Keep main context\n");
  let result = f.run(["context", "render"], worktree);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(readFileSync(join(f.repo, "AGENTS.md"), "utf8"), "Keep main context\n");
  assert.match(readFileSync(join(worktree, "AGENTS.md"), "utf8"), /^# AGENTS.md/);
  assert.match(readFileSync(join(worktree, "CLAUDE.local.md"), "utf8"), /^# CLAUDE.local.md/);
  result = f.run(["context", "render", "--all-worktrees"]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(readFileSync(join(f.repo, "AGENTS.md"), "utf8"), /^# AGENTS.md/);
  assert.ok(f.calls().every(call => call.command === "docker" && call.args[0] === "ps"));
});

test("Create a Ledidi worktree with context but without preparing dependencies", (t) => {
  const f = fixture(t);
  const result = f.run(["worktree", "create", "docs-only", "docs-only"], f.repo);
  assert.equal(result.status, 0, result.stderr);
  const worktree = join(f.repo, ".worktrees/docs-only");
  assert.match(readFileSync(join(worktree, "AGENTS.md"), "utf8"), /^# AGENTS.md/);
  assert.match(readFileSync(join(worktree, "CLAUDE.local.md"), "utf8"), /^# CLAUDE.local.md/);
  assert.deepEqual(f.calls(), []);
});

test("Keep a worktree intact when destruction receives help or unknown arguments", (t) => {
  const f = fixture(t);
  const worktree = join(f.directory, "worktree");
  f.git("worktree", "add", "-b", "feature", worktree);
  assert.equal(f.run(["worktree", "destroy", "--help"], worktree).status, 0);
  assert.equal(f.run(["worktree", "destroy", "--typo"], worktree).status, 2);
  assert.ok(existsSync(join(worktree, ".git")));
  assert.deepEqual(f.calls(), []);
});

test("Destroy a stackless clean worktree while keeping its branch", (t) => {
  const f = fixture(t);
  const worktree = join(f.directory, "worktree");
  f.git("worktree", "add", "-b", "feature", worktree);
  const result = f.run(["worktree", "destroy"], worktree);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(existsSync(worktree), false);
  assert.match(f.git("branch", "--list", "feature"), /feature/);
  assert.ok(f.calls().every(call => call.command === "docker" && ["info", "ps"].includes(call.args[0])));
});

test("Use the same startup workflow for stack up and the old start alias", (t) => {
  const f = fixture(t);
  f.env.DEV_TEST_DOCKER = "allow";
  writeFileSync(join(f.repo, "docker-compose.yml"), "services:\n  postgres:\n    image: postgres\n");
  let result = f.run(["stack", "up", "postgres"], f.repo);
  assert.equal(result.status, 0, result.stderr);
  const first = f.calls();
  assert.ok(first.some(call => call.args.includes("up") && call.args.includes("--wait")));
  assert.match(readFileSync(join(f.repo, "AGENTS.md"), "utf8"), /^# AGENTS.md/);
  result = f.run(["start", "postgres"], f.repo);
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(f.calls().slice(first.length), first);
  assert.equal(f.calls().some(call => call.command === "npm"), false);
});

test("Keep database volumes on down and remove them only on destroy", (t) => {
  const f = fixture(t);
  f.env.DEV_TEST_DOCKER = "allow";
  writeFileSync(join(f.repo, "docker-compose.yml"), "services:\n  postgres:\n    image: postgres\n");
  let result = f.run(["stack", "down"], f.repo);
  assert.equal(result.status, 0, result.stderr);
  const down = f.calls().find(call => call.args.includes("down"));
  assert.ok(down);
  assert.equal(down.args.includes("-v"), false);
  assert.ok(existsSync(join(f.env.DEV_STACKS_DIR, "repo")));

  const previousCalls = f.calls().length;
  result = f.run(["stack", "destroy", "--yes"], f.repo);
  assert.equal(result.status, 0, result.stderr);
  const destroy = f.calls().slice(previousCalls).find(call => call.args.includes("down"));
  assert.ok(destroy.args.includes("-v"));
  assert.ok(destroy.args.includes("--rmi"));
  assert.equal(existsSync(join(f.env.DEV_STACKS_DIR, "repo")), false);
});

test("Refuse non-interactive stack destruction without explicit confirmation", (t) => {
  const f = fixture(t);
  f.env.DEV_TEST_DOCKER = "allow";
  writeFileSync(join(f.repo, "docker-compose.yml"), "services:\n  postgres:\n    image: postgres\n");
  const result = f.run(["stack", "destroy"], f.repo);
  assert.equal(result.status, 1);
  assert.equal(f.calls().some(call => call.args.includes("down")), false);
});

test("Refuse to destroy the main checkout or a dirty worktree", (t) => {
  const f = fixture(t);
  assert.equal(f.run(["worktree", "destroy"], f.repo).status, 1);
  const worktree = join(f.directory, "worktree");
  f.git("worktree", "add", "-b", "feature", worktree);
  writeFileSync(join(worktree, "unfinished.txt"), "Keep this work\n");
  assert.equal(f.run(["worktree", "destroy"], worktree).status, 1);
  assert.equal(readFileSync(join(worktree, "unfinished.txt"), "utf8"), "Keep this work\n");
  assert.deepEqual(f.calls(), []);
});

test("Preserve persisted checkout identity and saved slots across the rename", (t) => {
  const f = fixture(t);
  const worktree = join(f.directory, "feature-tree");
  f.git("worktree", "add", "-b", "feature", worktree);
  const stackDirectory = join(f.env.DEV_STACKS_DIR, "feature-tree");
  mkdirSync(stackDirectory, { recursive: true });
  writeFileSync(join(stackDirectory, "worktree-slot"), "3\n");
  const result = spawnSync("bash", ["-c", '. "$1"; dev_checkout_id_for_repo "$2"; dev_stack_dir_for_repo "$2"; dev_slot_for_repo "$2"; printf "%s\\n" "$DEV_CHECKOUT_LABEL"; dev_slugify "!!!"',
    "test", join(f.tools, "lib/checkout.sh"), worktree], { env: f.env, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.stdout.trim().split("\n"), ["feature-tree", stackDirectory, "3", "com.ledidi.dev-workspace", "workspace"]);
  assert.deepEqual(f.calls(), []);
});

for (const script of ["wt-up", "wt-down", "setup-stack", "tunnel", "sync-context", "sync-agent-configs", "browser",
  "claude-notify", "codex-notify", "cursor-notify", "mcp-datadog"]) {
  test(`Keep ${script} help free of side effects`, (t) => {
    const f = fixture(t);
    const result = spawnSync("bash", [join(source, `${script}.sh`), "--help"], {
      cwd: f.directory, env: f.env, encoding: "utf8", timeout: 10000,
    });
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /Usage:/);
    assert.deepEqual(f.calls(), []);
  });
}
