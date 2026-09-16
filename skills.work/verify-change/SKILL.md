---
name: verify-change
description: Scope and reuse Ledidi checks for an edit or branch, handle failures, and choose commit and push verification.
---

# Verify a Ledidi change

This skill owns check scope and push gates; `dev-stack` owns setup commands.

## Select the scope

Record the task's starting HEAD and existing changes before editing. Identify
which of those changes belong to the task. Include staged, unstaged, and
relevant untracked files in verification.

| Work | Verification scope |
|------|--------------------|
| A follow-up edit or related feedback fixes | The task's changes since starting HEAD, including affected dependencies and consumers. |
| Opening a PR or explicitly verifying a branch | The feature diff against the PR's actual base, including a parent PR in a stack, or the intended target for unpublished work. |
| A rebase or merge | The rewritten feature and interfaces affected by the incoming changes. Compare the old and new feature diffs before choosing checks. |
| Pushing an already verified commit | Reuse valid results; check whether any relevant inputs changed. |

Fetch the comparison base when establishing branch or restack scope. Keep that
revision during verification unless the base changes materially. Earlier PR
changes alone do not broaden a follow-up edit into whole-branch verification.
Inspect schema, generation inputs, dependencies, and consumers before excluding
a workspace with no direct edits. Hook path filters are not a dependency graph.

Choose the smallest checks that prove the affected behavior. For test-only
edits, run the changed test files and relevant static checks. For component
states, prefer focused integration or Storybook checks. A full suite is needed
when requested or when the affected behavior cannot be covered reliably by a
smaller selection; it means the selected workspaces, not the whole monorepo.

Batch related edits before expensive final checks. Use focused tests during
iteration, then cover the final diff once. After a fix, rerun affected checks;
a failing file does not by itself require repeating every passing suite.

## Reuse evidence

Keep a short verification record in session context or an existing task
handoff: checkout, checked revision or uncommitted diff, comparison base,
command and selection, result, and relevant dependency/schema inputs. Reuse a
passing result while those inputs remain unchanged. Across sessions, inspect
the recorded evidence and intervening diff before relying on it. A green older
SHA alone is not evidence that a changed source tree passes.

Name the changed input or unresolved risk before repeating or broadening a
successful check. Formatting by a commit hook can change the checked files;
inspect its diff and rerun any affected check. Read actual hook output to
establish what ran.

When a task has substantial waiting, retain approximate time spent in setup,
local checks, review, and CI in the same record. Use observed durations, keep
overlapping runs separate, and report the dominant delay. No new tracker or
separate timing report is required.

## Browser checks and setup

Run E2E when requested, required by applicable domain context, or needed to
prove a changed critical flow. Inspect affected consumers for changes to
navigation, permissions, persistence, or embedded user flows. Reuse valid E2E
results during follow-up edits that do not affect those flows.

A draft or stacked PR may skip E2E in CI. At branch verification, run required
affected journeys locally if CI does not cover them. An ordinary push does not
itself require repeating that checkpoint. If the user defers E2E, name the
missing verification; skipped or deferred checks are not passes.

Before database-backed tests or hooks that reset a database, load `dev-stack`
for concurrency coordination even when setup is already complete. When required
checks need setup, prepare only the needed workspaces and services. Follow its
generation rules for generated types.

## Failures and hooks

Classify failures from evidence, not from whether master is green:

| Cause | Action |
|-------|--------|
| The task caused the failure | Fix it and rerun affected checks. |
| Required setup is missing | Prepare only what the selected checks need, then rerun. |
| Resource contention is suspected | Use `dev-stack` to reduce competing work and rerun failed files. A passing retry alone does not explain a recurring flake. |
| A hook selects unrelated incoming work | Apply the pre-push exception below. |
| Another pre-existing or unexplained failure | Report the command and evidence. Ask before expanding the task; do not bypass the failure. |

Pre-commit hooks must pass. Before an authorized push, selected checks must
pass. Run pre-push hooks by default, with these exceptions:

- Equivalent checks already passed for unchanged inputs. Inspect every selected
  pre-push command, including generation and schema/RLS checks. If each is
  covered by valid evidence, use `git push --no-verify` to avoid repetition.
- After a history rewrite, the hook selects workspaces changed only by incoming
  base commits. Confirm they are absent from `git diff --name-only <base>...HEAD`
  and are not affected dependencies or consumers. If those checks are the only
  uncovered or failing hooks and the feature's required checks passed, skip
  pre-push instead of preparing unrelated workspaces.
- The user explicitly requests skipping the push hook. Follow that request and
  report any verification omitted; it does not authorize unrelated changes or
  turn failures into passing results.

For rewritten remote history, use `--force-with-lease` tied to the recorded
remote SHA, adding `--no-verify` only under an exception above. A small diff
alone is not a reason to skip checks. Report a bypass and its evidence briefly.

Pushing or creating a draft does not start CI monitoring by itself. Load
`finish-pr` when the user requests making checks green or waiting for CI.
Otherwise report the available check state, including pending or failed checks,
without claiming the PR is fully verified.
