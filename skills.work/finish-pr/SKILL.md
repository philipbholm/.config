---
name: finish-pr
description: Monitor and fix Ledidi PR checks until green. Use for "make the PR green", "don't stop until all pr-checks are green", or after create-pr opens a PR.
---

# Finish a Ledidi pull request

Keep working until `pr-checks` succeeds for the PR's latest commit. This skill
owns the monitoring and repair loop; `verify-change` owns local check scope,
setup, failure classification, and push exceptions.

## Identify the PR and checks

Resolve the requested PR, or the current branch's PR when none is named.
Confirm the repository, PR number, head branch, and head commit. Use the
checkout holding that branch before editing; preserve unrelated local work.
If the target is ambiguous, ask which PR to finish.

Load `verify-change` before investigating failures. Identify the `pr-checks`
workflow and its runs for this PR using GitHub checks and workflow metadata.
Here, `pr-checks` means that workflow, not every optional check on GitHub.
Report other failing checks without expanding the repair scope unless asked.

## Monitor and repair

1. Inspect the latest run and attempt for the PR's current head. Read failing
   job logs and the relevant workflow configuration before choosing a fix.
   A successful run for an older commit does not verify the current head.
2. While checks are queued or running, use the harness's waiting or monitoring
   mechanism and recheck. Pending checks are not a blocker. Keep the user
   informed without ending the task merely because CI is still running.
3. Classify failures under `verify-change`. For an in-scope code fix, load
   `coding-standards`, make the fix, and run the required local checks. Load
   `write-commit`, commit only the fix, and push under `verify-change`.
   Return to monitoring after every push.
4. Rerun failed or cancelled jobs when the evidence supports a retry, such as
   a transient runner failure. Repeated identical failures need investigation,
   not blind reruns. Keep checks and assertions intact; repair the cause rather
   than disabling checks or accepting incorrect behavior to obtain green CI.
5. Before declaring completion, fetch the PR head and check state again. If
   the head changed, monitor the new head. Require a successful `pr-checks`
   run with every applicable job successful. A skipped job is acceptable only
   when its workflow condition makes it inapplicable, not when an upstream
   failure prevented it from running. Missing runs and cancelled jobs are not
   success; investigate the trigger or cancellation.

Continue while a scoped fix, inspection, or evidence-backed retry can make
progress. If completion requires new permission, unavailable credentials,
unrelated changes, or external action, report the blocker and ask for the
specific help needed. Preserve the worktree and completed fixes. Do not report
the PR as finished while the completion condition remains unmet.

## Report the result

Report the PR URL, verified head commit, check result, and fixes made. Include
any other failing checks or unresolved blocker. Follow the global draft-PR
rule; completing this skill does not authorize merging or changing PR state.
