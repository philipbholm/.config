---
name: restack-pr
description: Restack Ledidi PRs after an upstream branch changes, merges, or becomes a new base. Rebase or port dependent features, update PR bases, push, and verify current checks.
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

For each PR, finish its parent first and then:

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
5. Load `finish-pr` and verify the PR's latest head before moving on. Recheck
   already-finished parents if their heads changed during the operation.

The feature diff is against the PR's actual base. Verification also covers
affected dependencies and consumers; using a narrower PR diff must not exclude
them or broaden `verify-change`'s hook exception.

Keep backup refs until the rewritten branches are pushed and verified, then
remove only the backup refs created here. On a blocker, retain the backups and
completed work and name the specific help needed. Report each PR's base, final
head, check result, and any dependent PR left outside scope. Keep worktrees and
stacks available unless teardown was requested.
