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

Load `cleanup-dev` before removing a worktree or its stack, including after a
PR merges. That skill owns eligibility, numbered approval for other candidates,
safe teardown, and leftover Docker resources. For a single-worktree teardown,
keep its inventory scoped to that worktree and its resources.

When a session ends with containers running, report the stack and ports.
