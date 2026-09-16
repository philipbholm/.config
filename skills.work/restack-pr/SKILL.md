---
name: restack-pr
description: Restack Ledidi PRs, verify affected changes, and push updated branches and bases. Wait for CI only when requested.
---

# Restack Ledidi pull requests

Load `worktree` to locate the existing checkouts and `verify-change` for checks
and push rules. Restacking alone needs no dependency setup or service startup.

## Establish the stack

Resolve the requested PRs in the correct repository. Fetch current remote refs
and record each PR's head branch, remote head SHA, base branch, base SHA, local
HEAD, worktree path, and pending changes. Establish parent-child relationships
from PR bases and commit history. Report dependent PRs outside the requested
scope without rewriting them.

Show the proposed base changes and worktree paths. Use the named base when the
user supplied one; otherwise follow the established stack. Ask only when the
target or conflicting local work remains ambiguous. Preserve unrelated work.

## Restack from parent to child

Restack, locally verify, and push each parent before its children. Complete the
requested stack before monitoring CI; a parent's pending CI does not prevent
preparing its child. For each PR:

1. Identify the feature's original commit range before rewriting history. Keep
   a temporary local backup ref and record the original remote head for the
   force-with-lease check. Distinguish parent commits, feature commits, and merge
   commits. After a squash merge, ancestry alone cannot identify which parent
   changes already landed; compare patches and the merged PR evidence.
2. Rebase the feature range onto the new base. Use `git rebase --onto` only after
   establishing its old boundary; do not replay the former parent's changes as
   feature commits. If the new base changed interfaces, port the feature to the
   new structure under `coding-standards`. Load `resolving-merge-conflicts` for
   conflicts and `write-commit` for new commit messages.
3. Compare `git diff <new-base>...HEAD` and the rewritten commit range with the
   original feature. Check for dropped behavior, duplicated parent changes, and
   unrelated work. Run checks under `verify-change`, including dependencies and
   consumers affected by the new base.
4. Push using a lease tied to the recorded remote SHA. If the remote changed,
   inspect and incorporate that work before retrying; never replace the lease
   with a force push. Update the PR's base when necessary. Preserve draft state.
   Load `write-pr` if the resulting scope requires a title or description change.
5. Record the pushed head and available CI state, then continue to the next
   child. If another session changes a parent, inspect that change before
   continuing; coordinate branch ownership under `worktree`.

After pushing the stack, load `finish-pr` only if CI monitoring was requested.
Monitor the final heads together. If a CI repair changes a parent, update and
verify affected children before declaring the stack green.

The feature diff is against the PR's actual base. Verification also covers
affected dependencies and consumers; using a narrower PR diff must not exclude
them from the selected checks.

Keep backup refs until the rewritten branches pass local verification and their
remote heads are confirmed; when CI monitoring was requested, keep them until
that succeeds too. Then remove only the backup refs created here. On a blocker,
retain the backups and
completed work and name the specific help needed. Report each PR's base, final
head, check result, and any dependent PR left outside scope. Keep worktrees and
stacks available unless teardown was requested.
