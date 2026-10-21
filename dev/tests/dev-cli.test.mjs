import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const source = fileURLToPath(new URL("..", import.meta.url));
const scripts = ["dev", "stack", "worktree-create", "worktree-destroy", "workspace-prepare",
  "stack-expose", "context-render", "context-inspect", "claude-context", "session-search", "agent-config-apply", "browser-launch-debug", "test-e2e", "story"];

function fixture(t) {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), "dev-cli-test-")));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const tools = join(directory, "dev");
  const bin = join(directory, "bin");
  const repo = join(directory, "repo");
  const home = join(directory, "home");
  const log = join(directory, "calls.jsonl");
  const effect = join(directory, "env-sourced");
  for (const path of [tools, bin, repo, join(home, ".config"), join(directory, "hooks")]) mkdirSync(path, { recursive: true });
  symlinkSync(source, join(home, ".config/dev"));
  for (const script of scripts) cpSync(join(source, `${script}.sh`), join(tools, `${script}.sh`));
  cpSync(join(source, "lib"), join(tools, "lib"), { recursive: true });
  cpSync(join(source, "context/ledidi-monorepo"), join(tools, "context/ledidi-monorepo"), { recursive: true });
  writeFileSync(join(tools, ".env.local"), 'printf sourced > "$DEV_TEST_EFFECT"\n');
  writeFileSync(log, "");
  for (const command of ["docker", "pg_ctl", "npm", "cloudflared", "rover", "lsof", "osascript", "terminal-notifier", "npx"]) {
    writeFileSync(join(bin, command), `#!${process.execPath}
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.DEV_TEST_LOG, JSON.stringify({ command: ${JSON.stringify(command)}, args, cwd: process.cwd(),
  locked: fs.existsSync(process.env.DEV_SLOT_LOCKDIR) }) + "\\n");
if (${JSON.stringify(command)} === "lsof" && args.includes("-iTCP:" + process.env.DEV_TEST_OCCUPIED_PORT)) process.exit(0);
process.exit(99);
`, { mode: 0o755 });
  }
  const env = {
    ...process.env,
    HOME: home,
    PATH: `${bin}:${process.env.PATH}`,
    DEV_MAIN_REPO: repo,
    DEV_STACKS_DIR: join(directory, "stacks"),
    DEV_SLOT_LOCKDIR: join(directory, "slot.lock"),
    DEV_TEST_LOG: log,
    DEV_TEST_EFFECT: effect,
    DEV_PG_BIN: bin,
    DEV_SCRIPTS_DIR: join(directory, "scripts"),
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

const commands = [[], ["worktree"], ["workspace"], ["stack"], ["context"], ["session"], ["agent-config"], ["browser"], ["test"], ["test", "e2e"], ["story"],
  ["worktree", "create"], ["worktree", "destroy"], ["workspace", "prepare"],
  ...["up", "down", "destroy", "list", "expose", "logs", "ps", "stop", "restart", "psql", "reap"].map(action => ["stack", action]),
  ["context", "render"], ["context", "show"], ["context", "check"], ["session", "search"],
  ["agent-config", "apply"], ["browser", "launch-debug"]];

for (const args of commands) {
  test(`Show help for dev ${args.join(" ")} without side effects`, (t) => {
    const f = fixture(t);
    const result = f.run([...args, "--help"]);
    assert.equal(result.status, 0, result.stderr);
    assert.match(result.stdout, /[Uu]sage: dev/);
    assert.deepEqual(f.calls(), []);
    assert.equal(existsSync(f.effect), false);
    assert.equal(existsSync(f.env.DEV_STACKS_DIR), false);
  });
}

for (const args of [["unknown"], ["worktree", "delete"], ["worktree", "destroy", "--force"],
  ["stack", "unknown"], ["stack", "start"], ["stack", "destroy", "--force"], ["stack", "list", "--all"],
  ["stack", "expose", "--unknown"], ["context", "render", "--unknown"],
  ["context", "show", "--unknown"], ["context", "check", "--unknown"], ["session", "search", "--unknown"],
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

test("Start Storybook in the worktree assigned to a slot", (t) => {
  const f = fixture(t);
  const worktree = join(f.directory, "storybook-worktree");
  f.git("worktree", "add", "-b", "storybook", worktree);
  mkdirSync(join(f.env.DEV_STACKS_DIR, "storybook-worktree"), { recursive: true });
  writeFileSync(join(f.env.DEV_STACKS_DIR, "storybook-worktree/worktree-slot"), "3\n");
  mkdirSync(join(worktree, "apps/registries-frontend/node_modules"), { recursive: true });
  writeFileSync(join(worktree, "apps/registries-frontend/package.json"), "{}\n");
  f.env.DEV_TEST_OCCUPIED_PORT = "6012";

  const result = spawnSync("bash", [join(f.tools, "story.sh"), "3"], {
    cwd: f.directory, env: f.env, encoding: "utf8",
  });

  assert.equal(result.status, 99, result.stderr);
  assert.match(result.stdout, new RegExp(`Storybook: ${worktree.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")} \\(slot 3\\)`));
  assert.match(result.stdout, /URL: http:\/\/localhost:6013/);
  assert.deepEqual(f.calls().map(({ command, args }) => ({ command, args })), [
    { command: "lsof", args: ["-nP", "-iTCP:6012", "-sTCP:LISTEN"] },
    { command: "lsof", args: ["-nP", "-iTCP:6013", "-sTCP:LISTEN"] },
    { command: "npm", args: ["run", "storybook"] },
  ]);
  assert.equal(f.calls().at(-1).cwd, join(worktree, "apps/registries-frontend"));
});

test("Reject a Storybook slot that has no assigned worktree", (t) => {
  const f = fixture(t);
  const result = spawnSync("bash", [join(f.tools, "story.sh"), "4"], {
    cwd: f.directory, env: f.env, encoding: "utf8",
  });
  assert.equal(result.status, 2);
  assert.match(result.stderr, /no worktree is assigned to slot 4/);
  assert.deepEqual(f.calls(), []);
});

test("Show story help without inspecting worktrees", (t) => {
  const f = fixture(t);
  const result = spawnSync("bash", [join(f.tools, "story.sh"), "--help"], {
    cwd: f.directory, env: f.env, encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /story <slot>/);
  assert.deepEqual(f.calls(), []);
});

test("List stacks outside a Git repository without generating stack files", (t) => {
  const f = fixture(t);
  const result = f.run(["stack", "list"]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Shared PostgreSQL: stopped/);
  assert.match(result.stdout, /No dev stacks running/);
  assert.equal(existsSync(f.env.DEV_STACKS_DIR), false);
  assert.deepEqual(f.calls().map(call => call.command), ["pg_ctl"]);
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
  assert.equal(existsSync(join(worktree, "CLAUDE.local.md")), false);
  result = f.run(["context", "render", "--all-worktrees"]);
  assert.equal(result.status, 0, result.stderr);
  assert.match(readFileSync(join(f.repo, "AGENTS.md"), "utf8"), /^# AGENTS.md/);
  assert.equal(existsSync(join(f.repo, "CLAUDE.local.md")), false);
  assert.deepEqual(f.calls(), []);
});

test("Create a Ledidi worktree with context but without preparing dependencies", (t) => {
  const f = fixture(t);
  const result = f.run(["worktree", "create", "docs-only", "docs-only"], f.repo);
  assert.equal(result.status, 0, result.stderr);
  const worktree = join(f.repo, ".worktrees/docs-only");
  assert.match(readFileSync(join(worktree, "AGENTS.md"), "utf8"), /^# AGENTS.md/);
  assert.equal(existsSync(join(worktree, "CLAUDE.local.md")), false);
  assert.deepEqual(f.calls(), []);
});

test("Render AGENTS.md into a worktree that git creates outside dev", (t) => {
  const f = fixture(t);
  assert.equal(f.run(["context", "render"], f.repo).status, 0);
  assert.match(readFileSync(join(f.repo, ".git/info/exclude"), "utf8"), /^\/AGENTS\.md$/m);
  const worktree = join(f.directory, "harness-worktree");
  f.git("worktree", "add", "-b", "harness-worktree", worktree);
  const agents = readFileSync(join(worktree, "AGENTS.md"), "utf8");
  assert.match(agents, /^# AGENTS.md/);
  assert.match(agents, /No dev stack is running for this worktree/);
  assert.equal(f.git("-C", worktree, "status", "--porcelain"), "");
});

test("Give Claude Code the AGENTS.md of the session's own checkout", (t) => {
  const f = fixture(t);
  const worktree = join(f.repo, ".worktrees/nested");
  f.git("worktree", "add", "-b", "nested", worktree);
  const session = (cwd) => spawnSync("bash", [join(f.tools, "claude-context.sh")], {
    cwd, env: { ...f.env, CLAUDE_PROJECT_DIR: cwd }, encoding: "utf8",
  });
  let result = session(worktree);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /^# AGENTS.md/);
  assert.match(result.stdout, /No dev stack is running for this worktree/);
  assert.doesNotMatch(result.stdout, /Main Checkout/);
  result = session(f.directory);
  assert.equal(result.status, 0, result.stderr);
  assert.equal(result.stdout, "");
});

test("Detect stale rendered context without changing either checkout file", (t) => {
  const f = fixture(t);
  const worktree = join(f.directory, "feature-context");
  f.git("worktree", "add", "-b", "feature-context", worktree);
  assert.equal(f.run(["context", "render"], worktree).status, 0);
  const agents = join(worktree, "AGENTS.md");
  writeFileSync(agents, "Stale instructions\n");
  const result = spawnSync("bash", [join(f.tools, "context-render.sh"), "--check"], {
    cwd: worktree, env: f.env, encoding: "utf8",
  });
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stdout, /Stale or missing context:.*AGENTS.md/);
  assert.equal(readFileSync(agents, "utf8"), "Stale instructions\n");
  assert.deepEqual(f.calls(), []);
});

test("Show the actual worktree and saved endpoints without starting services", (t) => {
  const f = fixture(t);
  const worktree = join(f.directory, "port-context");
  f.git("worktree", "add", "-b", "port-context", worktree);
  mkdirSync(join(f.env.DEV_STACKS_DIR, "port-context"), { recursive: true });
  writeFileSync(join(f.env.DEV_STACKS_DIR, "port-context/worktree-slot"), "3\n");
  assert.equal(f.run(["context", "render"], worktree).status, 0);
  f.env.DEV_CONTEXT_HOME = join(f.directory, "home");
  const result = f.run(["context", "show", "--json"], worktree);
  assert.equal(result.status, 0, result.stderr);
  const report = JSON.parse(result.stdout);
  assert.equal(report.checkout, worktree);
  assert.equal(report.main_checkout, f.repo);
  assert.equal(report.branch, "port-context");
  assert.equal(report.slot, "3");
  assert.ok(report.rendered_urls.includes("http://localhost:3303/en/registries"));
  assert.deepEqual(f.calls(), []);
});

test("Check shared skill wiring and fail on a broken link", (t) => {
  const f = fixture(t);
  const home = join(f.directory, "home");
  const skill = join(f.directory, "skills/example");
  const globalSource = join(f.directory, "agents/AGENTS.md");
  f.env.DEV_CONTEXT_HOME = home;
  for (const path of [skill, join(f.directory, "agents"), join(home, ".claude/skills"),
    join(home, ".agents/skills"), join(home, ".codex")]) mkdirSync(path, { recursive: true });
  writeFileSync(globalSource, "Shared rules\n");
  writeFileSync(join(skill, "SKILL.md"), "---\nname: example\ndescription: Example\n---\n");
  for (const target of [join(home, ".claude/CLAUDE.md"), join(home, ".codex/AGENTS.md"), join(home, "AGENTS.md")])
    symlinkSync(globalSource, target);
  for (const target of [join(home, ".claude/skills/example"), join(home, ".agents/skills/example")])
    symlinkSync(skill, target);
  writeFileSync(join(f.tools, "context/ledidi-monorepo/AGENTS.md"), "# AGENTS.md\n\n| Request | Skill |\n| Example | `example` |\n");
  assert.equal(f.run(["context", "render"], f.repo).status, 0);
  let result = f.run(["context", "check"], f.repo);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  rmSync(join(home, ".claude/skills/example"));
  symlinkSync(join(f.directory, "missing"), join(home, ".claude/skills/example"));
  result = f.run(["context", "check"], f.repo);
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stdout, /Missing Claude Code skill: example/);
  writeFileSync(join(skill, "SKILL.md"), "---\nname: example\ndescription: Example\n---\nLoad `missing-skill` before working.\n");
  result = f.run(["context", "check"], f.repo);
  assert.match(result.stdout, /Missing referenced skill missing-skill/);
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
  assert.deepEqual(f.calls(), []);
});

function ledidiCheckout(f, cwd = f.repo) {
  writeFileSync(join(cwd, "docker-compose.yml"), "services:\n  registries:\n    environment:\n      - PORT=4000\n");
  mkdirSync(join(cwd, "services/registries"), { recursive: true });
}

test("Reject the patient services before starting anything", (t) => {
  const f = fixture(t);
  ledidiCheckout(f);
  const result = f.run(["stack", "up", "--include-patient"], f.repo);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /patient services do not run natively yet/);
  assert.deepEqual(f.calls(), []);
  assert.equal(existsSync(f.env.DEV_STACKS_DIR), false);
});

test("Reject an unknown stack service before starting anything", (t) => {
  const f = fixture(t);
  ledidiCheckout(f);
  const result = f.run(["stack", "up", "studies"], f.repo);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /studies/);
  assert.deepEqual(f.calls(), []);
});

test("Refuse non-interactive stack destruction without explicit confirmation", (t) => {
  const f = fixture(t);
  ledidiCheckout(f);
  const stackDirectory = join(f.env.DEV_STACKS_DIR, "repo");
  mkdirSync(stackDirectory, { recursive: true });
  const result = f.run(["stack", "destroy"], f.repo);
  assert.equal(result.status, 1);
  assert.match(result.stderr, /--yes/);
  assert.ok(existsSync(stackDirectory));
});

test("Destroy a stopped worktree stack together with its saved slot", (t) => {
  const f = fixture(t);
  const worktree = join(f.directory, "feature");
  f.git("worktree", "add", "-b", "feature", worktree);
  ledidiCheckout(f, worktree);
  const stackDirectory = join(f.env.DEV_STACKS_DIR, "feature");
  mkdirSync(stackDirectory, { recursive: true });
  writeFileSync(join(stackDirectory, "worktree-slot"), "2\n");
  writeFileSync(join(worktree, "services/registries/.env.test.local"), "POSTGRES_URL=old\n");
  const result = f.run(["stack", "destroy", "--yes"], worktree);
  assert.equal(result.status, 0, result.stdout + result.stderr);
  assert.equal(existsSync(stackDirectory), false);
  assert.equal(existsSync(join(worktree, "services/registries/.env.test.local")), false);
  assert.match(readFileSync(join(worktree, "AGENTS.md"), "utf8"), /No dev stack is running for this worktree/);
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
  const result = spawnSync("bash", ["-c", '. "$1"; dev_checkout_id_for_repo "$2"; dev_stack_dir_for_repo "$2"; dev_slot_for_repo "$2"; dev_slugify "!!!"',
    "test", join(f.tools, "lib/checkout.sh"), worktree], { env: f.env, encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(result.stdout.trim().split("\n"), ["feature-tree", stackDirectory, "3", "workspace"]);
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
