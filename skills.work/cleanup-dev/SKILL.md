---
name: cleanup-dev
description: Clean up stale Ledidi worktrees, dev stacks, and leftover Docker resources. Automatically remove safe merged-PR worktrees; present other candidates as numbered choices for approval. Inspection-only requests remain read-only.
---

# Clean up Ledidi development resources

Inventory first. On a cleanup request, remove eligible merged-PR worktrees and
their exclusive stack resources, then ask which remaining candidates to
remove. Creating or editing this skill, or asking for an inspection, does not
start cleanup.

Read [Resource inspection and removal](references/resources.md) before
inspecting or removing Docker resources. Use the existing dev tools where
their resolved targets match the approved inventory. Cleanup needs no service
startup, dependency installation, or image build.

## Inventory and evaluate

1. Identify the main checkout and all registered worktrees, including older
   Claude and Codex locations. Record each absolute path, branch, HEAD, locked
   or prunable state, tracked changes, and untracked files. Check ignored files
   for unique work, especially `.scratch`, notes, exports, and local data;
   ordinary clean Git status does not account for them. Inspect filenames and
   metadata without exposing secrets or patient data.
2. Resolve the PR in the correct GitHub repository using branch identity and
   commit evidence. Record its URL, state, merge time, and final head commit.
   A closed PR is not a merged PR. An old merged PR on a reused branch does not
   authorize removing newer work. Account for squash and rebase merges using
   the PR's final head, not just Git ancestry against master. Missing or
   ambiguous PR evidence makes the worktree an approval candidate.
3. Map running and stopped containers, images, volumes, networks, and saved
   stack state to exact checkouts. Include resources whose containers or
   directories were manually deleted, and older slots belonging to a checkout.
   Keep shared resources and uncertain ownership separate from each stack.
4. Recommend keep or remove using PR state, pending work, recent commits and
   PR activity, other worktrees depending on local files, and evidence of an
   active agent or development session. Age and stopped containers alone do
   not prove that work is disposable.

## Automatic cleanup after merge

A worktree qualifies only when all of these are confirmed:

- Its matching PR is merged, with no commits beyond the merged work or other
  local-only commits that would become inaccessible.
- It has no uncommitted work or unique untracked or ignored material. Discard
  only confirmed reproducible dependencies, build output, and managed context.
- It is neither the main checkout nor locked, in active use, or needed for
  another worktree's local files.
- Resource ownership is unambiguous. Its stack has no shared consumers or
  saved database data identified for retention.

Announce the worktree and stack to be removed, including database-volume loss,
then remove them without requesting another confirmation. Leave Git branches
and remote refs intact. Retain any candidate that fails a condition for the
numbered approval list. Green checks or the end of a session are not cleanup
conditions. Stack restarts and rebuilds are maintenance, not cleanup.

## Numbered approval

Give every remaining candidate a stable number and an explicit recommendation.
Use one row per worktree with its stack, or per independently removable group
of leftover resources. Separate image-only cleanup from database-volume loss.

| # | Worktree or resource group | PR state and activity | Recommendation and reason | What deletion removes |
|---|----------------------------|-----------------------|---------------------------|-----------------------|

Keep the exact path, HEAD, Docker context, project labels, resource IDs, and
volume names behind each number in the conversation or a local manifest.
Show full paths when names collide. Explain any unsaved work or retained data
before asking: "Reply with the numbers to clean up, for example 2, 4."

The reply authorizes only the listed resources and disclosed data loss. Keep
unselected entries. Do not renumber an outstanding list, add newly discovered
resources to an approved group, or treat approval to remove images as approval
to remove volumes. Save unique files outside the target before teardown if the
user chooses preservation; do not silently commit, stash, or discard them.

## Remove and verify

Immediately before each removal, recheck PR state, HEAD, pending files, active
use, Docker context, ownership, and resource consumers. If the inventory or
data-loss scope changed, keep the target and ask again. Stop that target on a
failed safety check or removal; continue only with independent approved targets.

For an eligible worktree, run `dev worktree destroy` from that exact checkout.
The command removes its stack and checkout but keeps the Git branch. Return
the calling shell to the main checkout afterwards. Never force worktree
removal or use a harness-native delete action. For approved stack-only cleanup,
run `dev stack destroy --yes` from the owning checkout. The main checkout
itself is never removable; its stack requires explicit approval as a separate
entry. Handle leftover resources under the reference's ownership checks.

Check Git registration and every inventoried Docker resource after teardown.
Report what was removed, what remains, and failures. Commits remain recoverable
through retained branches; deleted database volumes and discarded local files
have no recovery guarantee. Report Docker's measured space change, not the sum
of image sizes whose layers may be shared.
