---
name: fix-pr-feedback
description: Use when addressing code review feedback — either reviewer comments on a GitHub pull request, or a pasted list of issues to work through.
argument-hint: "[pr number | url | branch | list of issues]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, TaskCreate, TaskUpdate, TaskList
---

# Fix Review Feedback

Work through review feedback one item at a time: understand it, decide whether
it's right, fix what should be fixed, argue back on what shouldn't, and push.

## Input

`$ARGUMENTS` is either a PR reference (number, URL, or branch) or a pasted list
of issues (numbered, bulleted, or blank-line separated).

- **PR reference, or nothing** — find the PR. If there's no open PR for the
  current branch and you have no memory of which PR is meant, ask. A branch name
  means the PR for that branch. Read every review comment and inline thread:
  `gh pr view <n> --comments` and
  `gh api repos/{owner}/{repo}/pulls/<n>/comments`.
- **Pasted list** — use it in the order given. Later items may depend on
  earlier fixes.

## Before starting

1. `git branch --show-current`. If it's `master` or `main`, stop and ask — this
   skill commits.
2. Capture the base SHA (`git rev-parse HEAD`) so you can show the cumulative
   diff at the end.
3. Read `CLAUDE.local.md` at the repo root (or `CLAUDE.md`), plus the files it
   links to that are plausibly relevant. Those are the conventions the fixes
   have to follow.
4. Create a task per issue with `TaskCreate`, so progress is visible.

## Per issue

Work through them in order, one at a time.

**Understand it.** Read the code around the comment — the whole function, its
callers, the tests. If the comment references something you can't place, search
the PR conversation for context.

**Decide whether it's right.** Be critical of feedback; don't implement it
blindly. Feedback can rest on a misunderstanding of the code, conflict with
project conventions, or already be addressed. When you disagree, make no code
change and post a reply on that thread making the positive case for why the code
is the way it is — cite `file:line` and the convention. Don't just assert that
something is intentional; explain what it's doing and why that's the right
shape.

**If a comment is genuinely unclear, ask** rather than guessing what the
reviewer meant.

**Fix it.** The minimal change that addresses the issue, following the project's
conventions. Don't bundle unrelated cleanup.

**Test it.** If the fix changes behavior that isn't already covered, add a test
for that scenario. Skip when existing tests cover it or the change is cosmetic
(renames, comments, type-only) — and say so.

**Verify.** Type-check the touched workspaces, run the tests for the files you
touched plus any you added, and run lint if the project has it and it covers
what you changed.

**Commit.** Stage only the files for this issue and write a focused message. Let
the pre-commit hook run — never `--no-verify`. If it fails, fix the underlying
problem.

**Confirm the tree is clean** with `git status --short` before moving on. If it
isn't, something leaked from this issue — sort it out or record it as a problem
with this issue.

If an issue can't be resolved — verification keeps failing, the fix needs a
decision you can't make — stop working that issue, note what's blocking it, and
move to the next one. Report the blockage in the summary.

## Resolving threads

Resolve a thread only when the reviewer is not human. When in doubt, leave it
open.

## Push

`git push`, or `git push -u origin <branch>` if there's no upstream.

If the pre-push hook fails, capture its output verbatim, fix what it reports,
and retry. Two cycles at most — after that, report the failure rather than
continuing to push at it.

## Summary

Report honestly on every item from the original list:

```
Fixed (N):
  1. <issue summary> — <commit sha>

Disagreed (N):
  3. <issue summary> — <one-line reason, and where the reply was posted>

Not fixed (N):
  4. <issue summary> — <blocked by X | left for the reviewer to clarify | ...>

Push: <pushed to origin/{branch} | failed: reason>
```

Anything not fully fixed-and-committed belongs in "Not fixed", including items
blocked by verification failures and items with leftover working-tree changes.
