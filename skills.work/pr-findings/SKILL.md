---
name: pr-findings
description: Use when reviewing someone else's GitHub pull request and the findings should come back to me in chat so I can write the comments myself — this posts nothing on the PR. Skip when the comments should be posted for me; that is review-pr.
argument-hint: "[pr url | pr number]"
---

Review the PR and report what you found. I write and post the comments myself.

**Post nothing.** No `gh pr review`, no `gh pr comment`, no `gh api` write of
any kind, no approving, no requesting changes, no labels, no edits to the
branch. Only read. If a finding seems urgent enough to post, it still goes in
the report — tell me it's urgent instead.

If I gave a PR link or number, use it. If not, ask for one.

## Read first

- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/review-rules.md` — what to look for; the review corpus
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/testing.md`
- `/Users/philip/.config/dev/feedback/SYNTHESIZED_LEARNINGS.md` — guidelines distilled from earlier reviews of this repo
- repo-root `CLAUDE.local.md`, if you are inside the repo

## Read the PR

`gh pr view <pr> --json title,body,url,author,headRefOid,baseRefName,files` and
`gh pr diff <pr>`.

The diff alone hides things. Open the files the diff touches and read around the
change — a missing `authorize()`, a use case with no matching test, a story that
was never updated are all invisible in a hunk. For a very large PR, work through
it in file-group passes yourself; delegate only if I ask.

Keep `headRefOid` — it makes the permalinks below.

## What counts

Report a finding when you would want the author to change it before merge.
Anything `review-rules.md` marks as critical or "always flag" clears that bar on
its own. Be extremely skeptical and critical: unnecessary code, overengineering
and complication are findings, not taste.

Pure taste, a single redundant div, one debatable name — those are not major.
They go in the short list at the end, one line each, so I can decide.

Do not pad the report. Five real findings beat fifteen with ten guesses mixed
in. If the PR is clean, say so.

## Report

In chat. Nothing written to a file.

Open with one line: what the PR does, and whether you'd approve it, ask for
changes, or just comment.

Then each finding, most important first:

### 1. Short title

`services/registries/src/use-cases/update-form.ts:42` ·
[permalink](https://github.com/OWNER/REPO/blob/HEAD_REF_OID/path#L42)

**What** — one or two sentences on what the code does.

**Why** — the consequence. Which rule or which failure. Not "this violates the
style guide" but what actually goes wrong.

**Comment**

> The text I can paste.

Then, if the PR title, risk assessment or description have problems, a short
**PR structure** section — those are comments too, just not on a line.

Then **Minor** — at most ten, one line each, no suggested comment.

Close with what you could not check: tests you did not run, a stack you did not
start, a flow you could not follow. Say it plainly rather than implying the
review was complete.

## The suggested comment

It goes out under my name, so write it as me: first person, plain language,
short. Two or three sentences at most. Aim low enough that a five-year-old keeps
up.

Ask a question when you might be wrong about intent. State it directly when you
are not. Say what to do instead — a comment that only names the problem makes
the author guess.

Never mention Claude, an agent, or an automated review. Add a
` ```suggestion ` block only when the fix is a couple of literal lines.
