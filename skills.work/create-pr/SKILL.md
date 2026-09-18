---
name: create-pr
description: Implement or publish a Registries change as a draft Ledidi PR with verification, an SDLC risk assessment, and the matching risk label. Monitor CI only when requested.
---

# Create a Registries pull request

Adapted from the team's Create Pull Request skill. Scope product work to
`services/registries` and `apps/registries-frontend`, including affected shared
dependencies and consumers. Use the current checkout's
`docs/sdlc/development-process.md` (§10.8.1) as the policy source.

For “create a PR that …”, implement the requested change before publishing.
For a bare “create PR”, resume at the first unmet precondition. A preceding
specification or grilling session does not itself authorize implementation.

## Workflow

1. **Gather context.** Load `write-pr` and its work reference. Read the SDLC
   source above. Inspect status, staged and unstaged changes, untracked task
   files, branch tracking, and the feature diff against the intended base.
   Inspect existing PRs for this branch before creating another. Confirm the
   remote identifies `ledidi-as/ledidi-monorepo` and `gh` is authenticated.
   If authentication is missing, explain the required `gh auth login` step.
   Read the repository's default branch and available risk labels through `gh`.
   Use the intended parent branch for stacked PRs; otherwise use the default.
2. **Prepare and implement when needed.** Load `worktree` to create or enter
   the task's branch and worktree. Load `coding-standards` before edits or
   review. For a larger effort, use the existing agent tracker and keep its
   specification in the main checkout's `.scratch/`; follow the tracker setup
   rule if none exists. Small changes need no new specification. Implement
   only the authorized task and preserve unrelated working-tree changes.
3. **Verify the feature.** Load `verify-change` for branch comparison, scoped
   checks, result reuse, and failure handling. Load `dev-stack` when setup is
   needed. Satisfy the SDLC quality gates: affected static checks and unit and
   integration tests, plus E2E for changes to the UI or its backend interface.
   Use maintained workspace commands and include affected consumers. Inspect
   any formatter changes before including them. Keep the frames that browser
   verification puts on screen when the change is visual; the work reference
   says which of them the body needs. Report actual results and any
   deferred or blocked gates; a draft does not waive verification requirements.
4. **Assess and review.** Read the changed code and relevant callers. Identify
   actual Registries requirement or work-item references and classify the
   component and change risk under the work reference. Review the final diff
   under `coding-standards`; use `code-review` when its review-scope rule
   requires it. Supply the actual PR base and task-owned local paths so review
   includes the implementation before commit. Fix relevant findings and rerun
   affected checks. Refresh the review snapshot after fixes and confirm the
   final task content is covered before publishing; an earlier HEAD-only review
   does not cover uncommitted implementation.
5. **Commit and push.** Load `write-commit`, using its Registries SDLC message
   convention. Commit only uncommitted task changes; preserve existing commits
   unless rewriting them is requested. Push under `verify-change` after its
   required checks pass. Ordinary new branches use `git push -u origin HEAD`;
   rewritten history follows its lease and hook rules.
6. **Open a draft.** Use `gh pr create --draft --base <intended-base>` with the
   title and risk-assessment body from `write-pr`. Write the body to a temporary
   file and pass `--body-file`. Apply exactly one assessed label:
   `risk:standard`, `risk:minor`, or `risk:major`. Use the existing PR when one
   already covers the branch. Leave drafts in draft until explicitly asked to
   mark them ready. Open the PR URL in the browser.
7. **Report.** Inspect available CI state once. Load `finish-pr` only when
   asked to wait for CI or make checks green. Return the PR URL, risk level,
   verification and review results, pending or failed gates, and worktree and
   branch. Include running stack ports when relevant. Leave the worktree and
   stack available for follow-up work.

## Product behavior

Update `services/registries/docs/story-map/src/data/story-map.json` when
user-visible behavior changes. Otherwise tick the **Story map reviewed**
checkbox added by the bot. A story-map entry is not a URS identifier.
