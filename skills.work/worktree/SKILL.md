---
name: worktree
description: Create, enter, or remove a Ledidi worktree. Use for Ledidi branch setup, worktree setup, or teardown after a pull request merges.
---

# Ledidi worktrees

Use the harness-neutral scripts. Worktrees live at
`<repo>/.worktrees/<name>` for Claude Code, Codex, and Cursor Agent.

## Create or enter

1. Inspect `git status` and `git worktree list`. Uncommitted changes in the
   current checkout may be the work the user means; stop and ask before moving
   that work. When the target branch is already checked out in a worktree,
   continue there instead of creating another.
2. Choose one short kebab-case name for both branch and directory. Use
   `numeric-summary-family`, not a `feat/` or `worktree-` prefix. Stop and ask
   when that directory already exists.
3. A feature branch with commits in the main checkout comes along as-is with
   `wt-up <name> <branch>`. For new work, run `git fetch origin` and use
   `wt-up <name> <branch> origin/master`; `wt-up` does not fetch and the
   current `HEAD` may be unrelated.
4. Continue from the path printed by `wt-up`, then run `setup-stack`, naming
   any extra workspace the task touches. `setup-stack` installs dependencies
   and generates types; it starts no containers.

Report the worktree name, path, and branch after creation.

## Teardown

Keep a pull request's worktree and stack until the pull request is merged. A
green suite or the end of a session is not a teardown condition. Do not run
`dev down`, `dev nuke`, or `wt-down` before merge on your own initiative.

After merge, run `wt-down` from inside the worktree. `wt-down` removes the
worktree and its stack but leaves the branch. Do not use a harness-native
remove action, because it can delete the branch and orphan the Docker stack.

The main checkout has no worktree directory, so `wt-down` refuses to run
there. Never run `dev down` or `dev nuke` in the main checkout on your own
initiative.

`dev restart <service>` and `dev up --build <service>` are maintenance, not
teardown. When a session ends with containers running, report the stack and
ports.
