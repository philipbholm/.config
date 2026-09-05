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
   `dev worktree create <name> <branch>`. For new work, run `git fetch origin`
   and use `dev worktree create <name> <branch> origin/master`. Worktree
   creation does not fetch, and the current `HEAD` may be unrelated.
4. Continue from the path printed by `dev worktree create`. The command also
   writes the Ledidi agent context. For dependency preparation or service
   startup, load `dev-stack` and follow its setup policy.

Report the worktree name, path, and branch after creation.

## Teardown

Keep a pull request's worktree and stack until the pull request is merged. A
green suite or the end of a session is not a teardown condition. Do not run
`dev stack down`, `dev stack destroy`, or `dev worktree destroy` before merge
on your own initiative.

After merge, run `dev worktree destroy` from inside the worktree. The command
removes the worktree and its stack but leaves the branch. Do not use a
harness-native remove action, because it can delete the branch and orphan the
Docker stack.

The main checkout has no worktree directory, so `dev worktree destroy` refuses
to run there. Never run `dev stack down` or `dev stack destroy` in the main
checkout on your own initiative.

`dev stack restart <service>` and `dev stack up --build <service>` are
maintenance, not teardown. When a session ends with containers running, report
the stack and ports.
