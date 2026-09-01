---
name: review-pr
description: Use when reviewing a GitHub pull request and posting inline review comments on it
argument-hint: "[pr url | pr number]"
---

If provided a link to a PR review that, if not ask for a link to the PR. Then go
through the points below, and leave comments, ideally on the relevant code line
if not in mention in a summary.

Before reviewing, read the project context — it carries the rules this file does
not repeat:

- repo-root `CLAUDE.local.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/review-rules.md` — what to look for; the review corpus
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/testing.md`
- `/Users/philip/.config/dev/feedback/SYNTHESIZED_LEARNINGS.md` — guidelines distilled from earlier reviews of this repo

`review-rules.md` is the full list of what to raise. This file only covers how
to post it.

- Note on every comment that the review was done automatically by claude code
- post only comments that name a concrete problem or suggestion in the changed code
- for very large PRs, review in file-group passes yourself, delegate only if I ask for it

After submitting, list the comments you posted and use the `open` command to
open the URL to the review in my browser so i can verify it.
