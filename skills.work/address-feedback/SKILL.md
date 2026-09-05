---
name: address-feedback
description: Use when addressing code review feedback — either reviewer comments on a GitHub pull request, or a pasted list of issues to work through. Skip when the user only wants the feedback assessed or the fixes made without committing — this skill commits per issue and pushes.
argument-hint: "[pr number | url | branch | list of issues]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# Address Review Feedback

Work through review feedback one item at a time: understand it, decide whether
it's right, fix what should be fixed, argue back on what shouldn't, commit each
fix on its own, push once, then answer the threads.

You do the work yourself, in order — collect the items, then for each one:
triage, fix or draft a rebuttal, verify the code you touched, commit that one
item. When every item is done you run the full suite, push, and post the
answers. Nothing is posted to the PR until the fixes are pushed.

## Settle where the work happens, first

Everything downstream depends on this and nothing recovers from getting it
wrong. On a monorepo with worktrees the same paths exist in several checkouts
holding different code, so a fix made in the wrong tree edits the wrong file.

```bash
git branch --show-current
git worktree list
```

Confirm you are standing in the checkout that actually holds the branch under
review. If the branch is checked out in a worktree while you are in the main
clone, `cd` to that worktree before doing anything else. Then, in that
directory:

1. `git branch --show-current`. If it's `master` or `main`, stop and ask — this
   skill commits.
2. `git rev-parse HEAD` — the base SHA, for the cumulative diff at the end.
3. `git status --short`. Untracked scratch is normal. If there are modified
   *tracked* files, stop and ask: you commit by staging named files, and those
   changes would be swept into someone else's commit.

Read the repository's `AGENTS.md` or `CLAUDE.local.md` and load
`coding-standards` before changing code. In Ledidi, load `verify-change` for
check scope, setup, failure handling, and hook exceptions; elsewhere follow
the repository's verification instructions. Load `write-commit` before
committing a fix.

## Collect the feedback

`$ARGUMENTS` is either a PR reference (number, URL, or branch) or a pasted list
of issues.

**For a PR**, pull an index of the comments into a scratchpad file and read a
digest of it. You need only enough to answer three questions: how many items
there are, which are already settled, and whether the run is too big to start
unasked.

```bash
gh api --paginate repos/{owner}/{repo}/pulls/<n>/comments \
  --jq '.[] | {id, login: .user.login, path, line, sha: .original_commit_id[0:9], head: (.body[0:120] | gsub("\\s+"; " "))}'
gh api --paginate repos/{owner}/{repo}/issues/<n>/comments \
  --jq '.[] | {id, login: .user.login, head: (.body[0:120] | gsub("\\s+"; " "))}'
gh api --paginate repos/{owner}/{repo}/pulls/<n>/reviews \
  --jq '.[] | select(.body != "") | {id, login: .user.login, head: (.body[0:120] | gsub("\\s+"; " "))}'
```

Fetch each item's full body from the same endpoints when you reach it, so the
120-char heads in the index are all you carry until then.

**For a pasted list**, take it in the order given. A later item may assume an
earlier one has already landed, so keep that order when you work through them.

## Check the scale before starting

The default is all of them. Every automated finding gets evaluated — that's the
point, and a finding nobody looked at is a finding that stays open. Only what
was posted is in scope: a review can hold findings back into an HTML report,
and those are the user's to weigh.

Over roughly 40 items, stop and report the count and the automated/human split
before starting, so the size isn't a surprise. Take the lot unless the user
narrows it. The useful narrowing axes:

- **stale review batches.** Group the index by `original_commit_id`. A batch
  sitting on a revision the branch has long since moved past is often entirely
  obsolete — check the log first, and the user may rather re-request review than
  answer them.
- **threads already settled in conversation**, and the user's own replies.
  These are the only ones to drop on your own initiative, and say which.
- **by severity** — only if the user asks. Deferring the lowest severity on the
  PR leaves those threads unanswered.

## Telling automated comments from human ones

**Do not go by the author.** Automated reviews here are posted through ordinary
member accounts, and the same account carries both kinds. `user.type` is `User`
for every one of them.

Go by the body. Inline findings all open with the same header, whoever ran the
review: a severity in bold, a `·`, and a backticked slug —

```text
🟡 **Minor** · `test-coverage`
🟠 **Major** · `denial-of-service`
```

Match on the severity word, not the emoji: the colour varies for a given
severity. The words in use are `Critical`, `Blocker`, `Major`, `Minor` and
`Nit` — a reviewer driven by hand uses a wider set than any one skill defines.
Read the slug as prose and take it at face value; it is a pass name in one
review and a topic in the next, and nothing here depends on its value.

An inline comment is also automated when it *ends* with the attribution footer,
whether or not the header is there. Either signal is enough, and this only ever
moves a comment from human to automated.

**Review bodies are the part that varies.** Different people drive the reviewer
differently and each shape announces itself its own way. All four of these were
on one PR at once, the last from an older review that still named its model:

```text
🤖 **Automated review by Claude Code.**
## Automated review — PR #3707 … produced automatically by **Claude Code**
_This review was produced automatically by Claude Code._
🤖 **Automated review by Claude Code using claude-opus-4-6.**
```

So read it as *an announcement at the top of the body, or the footer at the
bottom*, not as a phrase to grep for. These four are samples and not a list to
match against. A person writing "the automated review is wrong here" is a
person.

Everything else is human — short prose, questions, bare ` ```suggestion ` blocks,
and any reply inside a thread an automated comment started, since a person
answering a bot's finding is a person. Genuine GitHub Apps (`dependabot`,
`renovate`, `codecov`, logins ending `[bot]`) are automated too.

When genuinely unsure, leave it human: that's the side where nothing is sent
without the user seeing it.

## Work each item

Take the items in order. For each one:

1. **Read the full comment**, then the surrounding code and the conventions for
   it. A review body can carry several findings at once, since findings with no
   valid inline location all land there. Split such a body into one item per
   finding, and answer them together in one reply on that body — GitHub has no
   separate thread to answer each on. If the item carries an `original_commit_id`, diff that SHA against the
   branch first — a comment on a revision the branch has moved past may already
   be answered in the log, and then it's `already-fixed`, not work.
2. **Decide the outcome:** `fix`, `already-fixed`, `disagree`, or `unclear`.
3. **If it's a fix**, make the change. Then **verify the code you touched** —
   build and lint it, and run the tests that cover it using workspace scripts.
   Classify failures under the verification instructions selected above.
4. **Commit that one item on its own.** Stage only the files this item touched,
   following those verification instructions. One commit per issue, so each
   answer can link to the commit that resolved it.
5. **If it's a disagreement**, write the rebuttal now, while you have the whole
   picture — the positive case with file:line. Don't commit anything.

Work them serially. A fix that changes a signature other items call goes first,
so the call sites are edited against the new shape. If two items collide on the
same lines, do them in whatever order reads cleanly and note the shared file in
both answers.

If a fix can't be made green and you can't see why, leave it in the tree, mark
it `attempted and dropped`, and keep going — say so at the end rather than
reverting silently.

## Check, then push

Once every item is worked:

1. **Run the full suite** within the selected verification scope, not just the
   per-item tests.
2. **Push when the selected verification instructions permit it.**
   Push before posting any answer — every answer to a fixed finding links to
   its commit, and an unpushed SHA 404s.
3. **If pushing is blocked, report why and hold the answers.** Automated
   answers carrying commit links are held rather than posted with dead links.

If the user asked you not to push, hold the automated answers too.

## Answer the threads

After pushing, not before. The split is by who is on the other end.

### Every automated finding gets an answer

All of them, whatever the outcome — nobody is waiting on a bot thread, and a
reviewer scrolling the PR should never have to guess what became of a finding.

| Outcome | What lands on the thread |
| --- | --- |
| fixed | `Fixed in [`596fcddbe`](…/pull/3707/commits/596fcddbe…) — bound the analysis grid to a maximum row count.` then two to four sentences on what was wrong and what changed |
| folded into another finding | the same, pointing at the commit that covers both and at the comment it duplicates |
| already on the branch | `Already fixed in [`a0dfd1af6`](…).` plus where it landed |
| refuted | the rebuttal, making the positive case with file:line |
| not actionable | that it wasn't specific enough to act on |
| attempted and dropped | that it wasn't fixed in this pass, and why |

Read the thread before you post, so a retry can't double-post. An automated
thread is resolved once its answer is posted — the finding is dealt with and
nobody is waiting on it. Check the project's own git docs first: a repo that
says otherwise wins over this line.

### Nothing aimed at a person is ever posted

Human comments get the same analysis and the same drafts, but the drafts come
back to the user. **Write them to a markdown file in your scratchpad directory**
and give the user the path. Per item the file carries:

- the link to the comment thread
- the permalink to the commit that answers it, if there is one
- the outcome, and a quote of what they said
- a draft reply in a fenced block, ready to copy

That includes items that were *fixed* — the user still has to answer those by
hand. A thread a person started is never resolved by you, however thoroughly it
was answered; that one is theirs to close.

With no PR in scope (a pasted list), everything comes back as drafts in that
file, since there is no thread to post to.

## Summary

First, **write the human drafts to the scratchpad file** and point at it — that
file is the deliverable. Then report on every item; an id in none of these
buckets is itself worth reporting.

```
Fixed (N) — one commit each, answered on their threads:
  c1. <issue summary> — <short sha>

Already fixed on the branch (N):
  c2. <issue summary> — landed in <sha>

Refuted (N):
  c3. <issue summary> — <one-line reason>

Not fixed (N):
  c4. <issue summary> — <left in tree: what and why>

Answered on the PR: N automated threads, N resolved. Nothing was sent to a person.

Waiting on you — N human items:
  <absolute path to the written file>
  c26 refuted · c68 fixed in 596fcddbe · …

Required suites: <scope and results>
Push: <pushed e9495317b..27cbdf66f | not pushed: reason>
```

Keep already-fixed out of "Refuted". They're a different answer — the comment
was right and the work is done — and burying them there misrepresents both
numbers. Don't re-quote the human drafts here; a one-line index of what's
waiting is enough, the file has them in full.

Then `git diff <baseSha>..HEAD --stat` for the cumulative picture.

Surface these rather than bury them, because each means something is unfinished:

- **required checks are unresolved at the tip** — report the failing command,
  the evidence for its cause, and whether it blocked the push.
- **commits are in "Fixed" but the push didn't happen** — the work is local and
  invisible on the PR, and the automated answers are held with it. Say what
  stopped it.
- **uncommitted changes beyond the untracked scratch you started with** — list
  the files. This is deliberate when a fix couldn't be made green, but the user
  has to decide what to do with it.
- **the branch was already red before any fix** — report that evidence and
  how the selected verification instructions apply.
- **an answer posted as a literal file path instead of its text** — post reply
  bodies with `-F` from a file, never `-f body=@…`, which sends the path. Read
  the thread back to confirm the text landed.
