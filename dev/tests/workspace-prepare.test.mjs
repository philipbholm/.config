import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { fileURLToPath } from "node:url";

const devDirectory = fileURLToPath(new URL("..", import.meta.url));

function fixture(t) {
  const directory = realpathSync(mkdtempSync(join(tmpdir(), "setup-stack-test-")));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const repo = join(directory, "repo");
  const bin = join(directory, "bin");
  const log = join(directory, "commands.jsonl");
  mkdirSync(repo);
  mkdirSync(bin);
  mkdirSync(join(directory, "hooks"));
  writeFileSync(log, "");
  const env = {
    ...process.env,
    PATH: `${bin}:${process.env.PATH}`,
    SETUP_TEST_LOG: log,
    GIT_CONFIG_COUNT: "1",
    GIT_CONFIG_KEY_0: "core.hooksPath",
    GIT_CONFIG_VALUE_0: join(directory, "hooks"),
  };
  const init = spawnSync("git", ["init", "--quiet", repo], { env, encoding: "utf8" });
  assert.equal(init.status, 0, init.stderr);
  writeFileSync(join(bin, "npm"), `#!${process.execPath}
const fs = require("node:fs");
const args = process.argv.slice(2);
fs.appendFileSync(process.env.SETUP_TEST_LOG, JSON.stringify({ cwd: fs.realpathSync(process.cwd()), args }) + "\\n");
if (process.env.SETUP_TEST_FAIL === args[0]) process.exit(1);
`, { mode: 0o755 });
  for (const command of ["docker", "dev", "rover"]) {
    writeFileSync(join(bin, command), `#!/bin/bash
echo '${command} must not run during dependency setup' >&2
exit 99
`, { mode: 0o755 });
  }
  function workspace(name, locked = true) {
    const path = join(repo, name);
    mkdirSync(path, { recursive: true });
    writeFileSync(join(path, "package.json"), '{"name":"test-workspace","private":true}');
    if (locked) writeFileSync(join(path, "package-lock.json"), "{}");
    return path;
  }
  workspace("services/registries");
  workspace("services/codelist");
  workspace("apps/registries-frontend");
  workspace("apps/shell");
  workspace("packages/components", false);
  writeFileSync(join(repo, "lefthook.yml"), "extends:\n  - apps/shell/lefthook.yml\n");

  return {
    directory,
    repo,
    env,
    run: (...args) => spawnSync("bash", [join(devDirectory, "dev.sh"), "workspace", "prepare", ...args], {
      cwd: repo, env, encoding: "utf8",
    }),
    calls: () => readFileSync(log, "utf8").trim().split("\n").filter(Boolean).map(JSON.parse),
    expected: (name, ...args) => ({ cwd: join(repo, name), args }),
  };
}

test("Require a workspace before doing any setup", (t) => {
  const f = fixture(t);
  const result = f.run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /Usage: dev workspace prepare/);
  assert.deepEqual(f.calls(), []);
});

test("Show help without preparing workspaces", (t) => {
  const f = fixture(t);
  const result = f.run("--help");
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.stdout, /Usage: dev workspace prepare/);
  assert.deepEqual(f.calls(), []);
});

test("Prepare only the named backend even when other workspaces have hooks", (t) => {
  const f = fixture(t);
  const result = f.run("services/registries");
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(f.calls(), [
    f.expected("services/registries", "ci", "--loglevel=warn"),
    f.expected("services/registries", "run", "generate", "--if-present"),
  ]);
  assert.doesNotMatch(result.stdout, /apps\/shell/);
});

test("Prepare the frontend without preparing backend services or a supergraph", (t) => {
  const f = fixture(t);
  const result = f.run("apps/registries-frontend");
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(f.calls(), [
    f.expected("apps/registries-frontend", "ci", "--loglevel=warn"),
    f.expected("apps/registries-frontend", "run", "generate", "--if-present"),
  ]);
});

test("Install every selected workspace before generating in selection order", (t) => {
  const f = fixture(t);
  const result = f.run("services/codelist", "apps/shell");
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(f.calls(), [
    f.expected("services/codelist", "ci", "--loglevel=warn"),
    f.expected("apps/shell", "ci", "--loglevel=warn"),
    f.expected("services/codelist", "run", "generate", "--if-present"),
    f.expected("apps/shell", "run", "generate", "--if-present"),
  ]);
});

test("Deduplicate paths and preserve lockfile-free packages", (t) => {
  const f = fixture(t);
  const result = f.run("packages/components/", "./packages/components", "packages/components");
  assert.equal(result.status, 0, result.stderr);
  assert.deepEqual(f.calls(), [
    f.expected("packages/components", "install", "--no-package-lock", "--loglevel=warn"),
    f.expected("packages/components", "run", "generate", "--if-present"),
  ]);
});

for (const invalid of ["--all", "services/missing", "services", "../outside", "/tmp", ".", ""]) {
  test(`Reject ${JSON.stringify(invalid)} before installing a valid preceding workspace`, (t) => {
    const f = fixture(t);
    const result = f.run("services/registries", invalid);
    assert.notEqual(result.status, 0);
    assert.deepEqual(f.calls(), []);
  });
}

test("Reject a workspace symlink that escapes the checkout", (t) => {
  const f = fixture(t);
  const outside = join(f.directory, "outside");
  mkdirSync(outside);
  writeFileSync(join(outside, "package.json"), "{}");
  symlinkSync(outside, join(f.repo, "services/external"));
  assert.notEqual(f.run("services/external").status, 0);
  assert.deepEqual(f.calls(), []);
});

test("Stop before generation when a selected install fails", (t) => {
  const f = fixture(t);
  f.env.SETUP_TEST_FAIL = "ci";
  const result = f.run("services/registries");
  assert.notEqual(result.status, 0);
  assert.deepEqual(f.calls(), [f.expected("services/registries", "ci", "--loglevel=warn")]);
});

test("Stop at a failed generator without expanding setup", (t) => {
  const f = fixture(t);
  f.env.SETUP_TEST_FAIL = "run";
  const result = f.run("services/registries", "services/codelist");
  assert.notEqual(result.status, 0);
  assert.deepEqual(f.calls(), [
    f.expected("services/registries", "ci", "--loglevel=warn"),
    f.expected("services/codelist", "ci", "--loglevel=warn"),
    f.expected("services/registries", "run", "generate", "--if-present"),
  ]);
});

test("Create a worktree without preparing dependencies", (t) => {
  const f = fixture(t);
  const commit = spawnSync("git", ["-c", "user.name=Setup Test", "-c", "user.email=setup-test@example.invalid",
    "-c", "commit.gpgsign=false", "commit", "--allow-empty", "-m", "Create fixture"], {
    cwd: f.repo, env: f.env, encoding: "utf8",
  });
  assert.equal(commit.status, 0, commit.stderr);
  const worktreeBase = join(f.directory, "worktrees");
  const result = spawnSync("bash", [join(devDirectory, "dev.sh"), "worktree", "create", "docs-only", "docs-only"], {
    cwd: f.repo, env: { ...f.env, WORKTREE_BASE: worktreeBase }, encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
  assert.match(readFileSync(join(worktreeBase, "docs-only", ".git"), "utf8"), /^gitdir:/);
  assert.deepEqual(f.calls(), []);
  assert.doesNotMatch(result.stdout, /run setup-stack/);
});
