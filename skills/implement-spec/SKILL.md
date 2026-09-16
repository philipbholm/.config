---
name: implement-spec
description: "Implement a specification in code."
disable-model-invocation: true
---

You have been provided a spec. This spec should have tickets associated with it, describing how to implement the spec.

The goal is a PR which implements the entire spec on a single branch.

The tickets are not a list of steps. They are a **task graph** with blocking relationships between them. This means there is always a **frontier** of tickets which are ready to be grabbed.

Communication to and from subagents should be sparse. Communicate primarily through **context pointers**: to the spec, tickets, research notes, and previous commits. Don't duplicate information already available via pointers.

Run independent implementer work in parallel when it shortens the task.
Keep one writer per branch and limit competing heavy builds and tests under
the repository's setup rules. In Ledidi, use `worktree` for ownership and
`dev-stack` for test concurrency.

## Steps

1. Read the spec and tickets. Read enough to understand the task graph.

2. (optional) Use an **exploration subagent** to conduct any exploration required by the tickets - relevant codebase files or external documentation. Ensure the exploration subagent can save files - it should save its markdown notes in a directory outside the repo, accessible by all future subagents. This lets **implementer subagents** focus on implementation rather than exploration.

3. Create a branch, and a draft PR. The PR should be marked as 'closing' the spec issue and tickets.

4. Use **implementer subagents** to implement each ticket. Each implementer subagent should work in its own worktree, on its own branch.

5. Once an **implementer subagent** completes, merge its work to the PR branch with a **merger subagent**.

6. When dependencies become satisfied, start the next independent tickets within
   the available worktree and test capacity.

7. Verify the combined final diff and review it under the repository's rules.
   In Ledidi, use `verify-change` to reuse valid checks and `coding-standards`
   to select self-review or independent review. Fix relevant findings with one
   writer on the PR branch and rerun affected checks.

8. Report implementation, local verification, review, and available CI results.
   In Ledidi, invoke `finish-pr` only when CI monitoring was requested; otherwise
   report pending checks. Leave the PR in draft until the user explicitly asks
   to mark it ready.

9. Clean up all **implementer subagent** worktrees.
