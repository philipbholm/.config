---
name: finish-pr
description: Monitor and fix Ledidi PR checks until green when requested. Creating, pushing, or restacking a PR alone does not invoke this skill.
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

Load `verify-change` and select branch verification, reusing valid local results.
Identify every workflow with a `pr-checks` job and its runs for this PR using
GitHub checks and workflow
metadata. Here, `pr-checks` means those workflows, not every optional check on GitHub.
Report other failing checks without expanding the repair scope unless asked.

Inspect the workflow condition for every skipped suite. For E2E suites skipped
because the PR is a draft or targets another branch, use `verify-change` to
identify required affected journeys. Reuse valid local results or run missing
checks before completion. Include affected consumers such as an app
embedding the changed frontend; standalone browser checks do not cover that
consumer. If a required local run is blocked, report the missing verification
and the specific blocker. Keep the PR in draft under the global rule.

## Monitor and repair

1. Inspect the latest run and attempt for the PR's current head. Read failing
   job logs and the relevant workflow configuration before choosing a fix.
   A successful run for an older commit does not verify the current head.
2. Record the head, workflow run IDs, and attempts. While checks are pending,
   use one monitor or poll those runs at roughly 30–60 second intervals. Reuse
   workflow conditions and logs already read for unchanged attempts; refresh
   discovery when the head, attempt, or workflow changes. Pending checks are not
   a blocker. Keep the user informed and continue until the requested result.
3. Classify failures under `verify-change`. For an in-scope code fix, load
   `coding-standards`, make the fix, and run the required local checks. Load
   `write-commit`, commit only the fix, and push under `verify-change`.
   Return to monitoring after every push.
4. Rerun failed or cancelled jobs when the evidence supports a retry, such as
   a transient runner failure. Repeated identical failures need investigation,
   not blind reruns. Keep checks and assertions intact; repair the cause rather
   than disabling checks or accepting incorrect behavior to obtain green CI.
5. Before declaring completion, fetch the PR head and check state again. If
   the head changed, monitor the new head. Require successful runs for every
   identified workflow with every applicable job successful. A skipped job is
   acceptable only when its workflow condition makes it inapplicable, not when an upstream
   failure prevented it from running. Missing runs and cancelled jobs are not
   success; investigate the trigger or cancellation.

Continue while a scoped fix, inspection, or evidence-backed retry can make
progress. If completion requires new permission, unavailable credentials,
unrelated changes, or external action, report the blocker and ask for the
specific help needed. Preserve the worktree and completed fixes. Do not report
the PR as finished while the completion condition remains unmet.

## Report the result

Report the PR URL, verified head commit, check result, and fixes made. Name
every skipped suite, its skip condition, and the local result when required.
When draft conditions skipped checks, say that draft checks passed and name
the checks that will run when the PR leaves draft. Reserve an all-checks-green
claim for checks that actually ran and passed. Include any other failing checks
or unresolved blocker. Follow the global draft-PR
rule; completing this skill does not authorize merging or changing PR state.
