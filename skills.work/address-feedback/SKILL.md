---
name: address-feedback
description: Assess or address code review feedback from a PR or pasted list. Use assess mode for relevance checks and suggested replies; fix mode verifies, commits, and pushes corrections. Skip fix mode when the user asks for edits without committing.
argument-hint: "[assess|fix] [pr number | url | branch | list of issues]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# Address review feedback

Choose the mode from the user's request. “Evaluate”, “is this still relevant”,
and requests for suggested fixes or replies use **assess** mode. Requests to
address or implement feedback use **fix** mode unless the user excludes commits.
Keep one outcome record per finding throughout the task.

## Assess without changing the branch

Read repository context, `coding-standards`, and
[Review quality](/Users/philip/.config/skills/code-review/references/review-quality.md).
For GitHub feedback, read [GitHub feedback](references/github.md) to collect the
full threads. Pin the PR's current head SHA and inspect that revision without
switching a dirty checkout. Read the surrounding code, tests, and intervening
commits; a stale comment can still describe a current defect.

Return one of **Relevant**, **Already fixed**, **Disagree**, or **Needs
investigation**, with evidence at the pinned revision. For a relevant finding,
show the smallest suggested correction and a short draft reply. Link an existing
fix when one exists. Recheck the PR head before reporting; reassess affected
findings if it changed.

Assessment makes no source edits, commits, pushes, replies, or thread-state
changes. A request to assess stops after reporting. Continue to fix mode when
implementation is already authorized by the conversation.

## Fix the findings

Assess each finding, verify and commit each fix separately, then push and
deliver the responses under the following steps.

## Locate the work and feedback

1. Check `git branch --show-current`, `git worktree list`, and
   `git status --short`. Enter the checkout holding the reviewed branch.
   In that checkout, stop and ask if the branch is master/main or the tree has
   existing tracked modifications. Preserve untracked work and capture HEAD
   for the cumulative diff.
2. Read repository context and load `coding-standards`. Read
   [Review quality](/Users/philip/.config/skills/code-review/references/review-quality.md)
   to assess the findings. In Ledidi, load `verify-change`; elsewhere follow
   the repository's verification instructions. Load `write-commit` before
   committing fixes.
3. For GitHub feedback, read [GitHub feedback](references/github.md) before
   collecting comments. For a pasted list, use the supplied items directly.
   Work through the requested scope; do not add findings withheld in a review's
   private report. Report the item count and give progress updates on long runs.

## Work each finding

Use dependency order, preserving the supplied order where dependencies allow.

Read the full finding and assess it under Review quality. Split a review body
containing several findings into separate items. Check whether a finding on
an older revision is already fixed; age alone does not make it obsolete.

For a valid issue, make the change and run the required checks. Commit only
that issue's fix, so the response can link to the commit. For a disagreement,
record the rebuttal with code references instead of changing code.

Use these outcomes consistently:

| Outcome | Record |
|---------|--------|
| Fixed | Verified correction and commit |
| Already fixed | Existing correction and its location or commit |
| Folded into another finding | The finding and commit that cover it |
| Disagree | Evidence and rebuttal |
| Unclear | Missing information or why the finding is not actionable |
| Blocked | Attempted work, failed check, and what is needed to continue |

When a fix remains unverified, mark it Blocked. Keep its changes out of later
commits. Continue independent findings only when their changes and verification
can remain separate; pause dependent or overlapping work and ask for direction.
Do not silently revert, stash, or commit the blocked changes.

## Verify and push

After processing the findings, run the full suite within the selected
verification scope. Push only when those verification instructions permit it.
If pushing is blocked or the user asked not to push, hold GitHub responses.

For GitHub, deliver responses under the reference's human/automated rules
after pushing. For a pasted list, return the outcomes and any draft responses
to the user; there are no threads to publish to.

## Report

Report every finding's outcome, fix commits, verification and push results,
and any replies posted or threads resolved. Link the human-response draft
file when one was needed. Include unresolved checks, blocked work, uncommitted
changes, and the specific action needed from the user. Keep the chat summary
short; the outcome record holds the detail.

Use `git diff <starting-head>..HEAD --stat` for the cumulative change summary.
