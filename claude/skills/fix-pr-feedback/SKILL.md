---
name: fix-pr-feedback
description: Use when addressing code review feedback — either reviewer comments on a GitHub pull request, or a pasted list of issues to work through. Skip when the user only wants the feedback assessed or the fixes made without committing — this skill commits per issue and pushes.
argument-hint: "[pr number | url | branch | list of issues]"
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Workflow, TaskCreate, TaskUpdate, TaskList
---

# Fix Review Feedback

Work through review feedback: understand each item, decide whether it's right,
fix what should be fixed, argue back on what shouldn't, and push.

The fixing runs as a workflow — every item is triaged at once, the results are
ordered into a dependency graph, and each level of that graph is applied in
parallel. You set the run up and report the outcome; the workflow does the work
in between, so the bulk of it never reaches this context.

## Settle where the work happens, first

Everything downstream depends on this and nothing recovers from getting it
wrong. **Subagents inherit this session's working directory, not the branch's.**
On a monorepo with worktrees those are routinely different checkouts of the same
repo, holding the same paths with different code — so an agent that isn't told
where to go will read, edit, and commit in whichever tree it landed in.

```bash
git branch --show-current
git worktree list
```

Work out the absolute path of the checkout that actually holds the branch under
review. That path is `cwd` in the workflow args, and the workflow refuses to
start without it. If the branch is checked out in a worktree while you're
standing in the main clone, `cwd` is the worktree — don't `cd` there yourself,
just pass it.

Then, in that directory:

1. `git branch --show-current`. If it's `master` or `main`, stop and ask — this
   skill commits.
2. `git rev-parse HEAD` for the base SHA.
3. `git status --short`. Pass the output verbatim as `preexisting`. Untracked
   scratch left lying around is normal and the workflow needs to know about it,
   or every level reports an unclean tree over the same stale directory. If
   there are modified *tracked* files, stop and ask: the workflow commits by
   staging named files, and those changes would be swept into someone else's
   commit.

**If the PR touches backend integration tests, bring up the database before you
start** — `dev up postgres -d` in that worktree. Verification runs `vitest` on
the tests each level touched, and an integration test with no database fails in
a way that looks exactly like a broken fix.

You don't need to read the project conventions yourself. Each agent reads
`CLAUDE.local.md` and its linked docs for the code it's actually looking at.

## Collect the feedback

`$ARGUMENTS` is either a PR reference (number, URL, or branch) or a pasted list
of issues.

**For a PR**, read an *index* of the comments — not the bodies. The workflow
fetches full text itself, and 70 comment bodies is 85 KB you'd have to carry
here and then retype into a tool call:

```bash
gh api --paginate repos/{owner}/{repo}/pulls/<n>/comments \
  --jq '.[] | {id, login: .user.login, path, line, sha: .original_commit_id[0:9], head: (.body[0:120] | gsub("\\s+"; " "))}'
gh api --paginate repos/{owner}/{repo}/issues/<n>/comments \
  --jq '.[] | {id, login: .user.login, head: (.body[0:120] | gsub("\\s+"; " "))}'
gh api --paginate repos/{owner}/{repo}/pulls/<n>/reviews \
  --jq '.[] | select(.body != "") | {id, login: .user.login, head: (.body[0:120] | gsub("\\s+"; " "))}'
```

Pipe those into a scratchpad file and read a digest of it. What you need from
the index is only enough to answer three questions: how many items there are,
which are already settled, and whether the run is too big to start unasked.

**For a pasted list**, take it in the order given, pass it as `issues`, and set
`orderedList: true` — that tells triage a later item may assume an earlier one
has landed.

## Check the scale before starting

An automated review on a large PR runs to eighty findings or more. That's one
triage agent each, and the run gets very large — the run this skill was tuned on
was 73 items, 130 agents, 95 minutes and 3.3M tokens.

Over roughly 40 items, stop and report the count and the automated/human split
before starting.

**The default is all of them.** Every automated finding gets evaluated —
that's the point of running this, and a finding nobody looked at is a finding
that stays open. Report the size so the cost isn't a surprise, then take the lot
unless the user narrows it. If they do want to narrow, the useful axes are:

- **stale review batches.** Group the index by `original_commit_id`. A batch
  sitting on a revision the branch has long since moved past is often entirely
  obsolete — on the tuning run, 23 of 73 items were one such batch and every one
  came back "already fixed on the branch". They're cheap now that triage diffs
  first, but the user may rather re-request review than answer them.
- **threads already settled in conversation**, and the user's own replies.
  These are the only ones to drop on your own initiative, and say which.
- **by severity** — only if the user asks. Deferring the `Nit`s leaves them
  unanswered on the PR.

## Telling automated comments from human ones

**Do not go by the author.** Automated reviews here are posted through ordinary
member accounts, and the same person's account carries both kinds — on one
recent PR, two accounts had 77 generated comments and 26 handwritten ones
between them. `user.type` is `User` for every one of them.

Go by the body. Inline findings all open with the same header, whoever ran the
review: a severity in bold (`Critical`, `Blocker`, `Major`, `Minor`, `Nit`), a
`·`, and a backticked category —

```text
🟡 **Minor** · `test-coverage`
🟠 **Major** · `denial-of-service`
```

Match on the severity word, not the emoji: the colour varies for a given
severity.

**Review bodies are the part that varies.** Different people drive the reviewer
differently and each shape announces itself its own way. All three of these were
on PR #3707 at once:

```text
🤖 **Automated review by Claude Code.**
## Automated review — PR #3707 … produced automatically by **Claude Code**
_This review was produced automatically by Claude Code._
```

So read it as *an announcement at the top of the body*, not as a phrase to grep
for. A person writing "the automated review is wrong here" is a person.

Everything else is human — short prose, questions, bare ` ```suggestion ` blocks,
and any reply inside a thread an automated comment started, since a person
answering a bot's finding is a person. Genuine GitHub Apps (`dependabot`,
`renovate`, `codecov`, logins ending `[bot]`) are automated too.

The workflow re-derives all of this from the body itself, so a mistake in the
index is recoverable. When genuinely unsure, leave it human: that's the side
where nothing is sent without the user seeing it.

## Run the workflow

Call `Workflow` with
`scriptPath: "/Users/philip/.claude/skills/fix-pr-feedback/workflow.js"` and
`args` as a **real JSON object, not a JSON string**. (The script parses a string
if it gets one, but that's a backstop, not the contract — it exists because
sending a string once cost a run its entire reply stage.)

For a PR, let the workflow fetch the comments:

```json
{
  "repo": "owner/name",
  "prNumber": 123,
  "branch": "<branch under review>",
  "baseSha": "<sha before this run>",
  "cwd": "<absolute path of the checkout holding that branch>",
  "preexisting": "?? docs/plans/",
  "push": true,
  "includeCommentIds": ["3718447767", "3718448792"],
  "excludeSeverities": ["Nit"]
}
```

`includeCommentIds` takes exactly those and nothing else — use it once the user
has picked a scope. Otherwise use `excludeCommentIds` for the settled threads and
`excludeSeverities` for the grades being deferred; the collect agent drops the
authenticated user's own comments either way. `push` defaults to true; set it
false only if the user said not to push.

For a pasted list, or a PR small enough that you already have the bodies, pass
`issues` instead and skip collection:

```json
{
  "cwd": "<absolute repo root>",
  "orderedList": false,
  "issues": [
    {
      "id": "c1",
      "body": "<the comment verbatim>",
      "file": "services/registries/src/foo.ts",
      "line": 42,
      "author": "some-reviewer",
      "isBot": false,
      "source": "inline",
      "commentId": "987654",
      "reviewedSha": "5ec3b7a72",
      "url": "https://github.com/..."
    }
  ]
}
```

`source` is `inline`, `issue`, or `review` — it decides both how a body is
fetched and where a reply goes. `commentId` is what threads a rebuttal; without
it one lands as a loose PR comment. `reviewedSha` is `original_commit_id`, and
it's what lets triage spot a comment the branch has already moved past. Omit
`file`/`line`/`commentId` for pasted items.

Run it once, over every item in scope. Don't drop items on your own judgement,
don't fix anything yourself first, and don't fall back to working through them
here because the list is short — a single item is a one-node graph and costs one
extra hop. The only narrowing allowed is the one the user asked for above.

### Then wait for it

**The `Workflow` call returns immediately with a task id. It has not done
anything yet.** The result arrives later as a task notification. Do not push, do
not summarize, and do not touch the repo until that notification arrives and you
have the returned object in hand — a `git push` issued now pushes an empty branch
while the edit agents are still running.

This workflow deliberately exceeds the default "medium" workflow size guideline
on a PR with more than a handful of comments: roughly two agents per item plus
three or four per graph level. That's the intended trade. Don't shrink it to fit.

### If it dies

A workflow that dies in script logic — after agents have run — should be
**resumed, not restarted**. Read the returned error, patch the script, and
re-invoke with `resumeFromRunId`: the unchanged prefix of `agent()` calls returns
from cache, so a triage pass that cost 25 minutes isn't paid twice. Editing a
prompt invalidates that agent and everything after it, which is usually what you
want.

Before resuming, check `git status` and `git log` — a dead run may have left
commits or a dirty tree. Check the agent count too: resume re-runs the suffix, so
if reply or commit agents had already fired, they'll fire again. Reply agents
check the thread before posting, so a repeat is safe; a repeat commit is not.

If it won't start at all, say so and fall back to working the items serially
here: triage, fix, verify, commit, one at a time, tracking them with
`TaskCreate`/`TaskUpdate`. Retry the workflow at most once.

## What it does

Worth knowing, because you report on it:

- **Collect** — one agent fetches the comments and returns metadata plus a short
  excerpt each. Skipped when you passed `issues`.
- **Triage** — one read-only agent per item, in parallel. Each fetches the full
  comment, reads the surrounding code and the conventions, and returns `fix`,
  `already-fixed`, `disagree`, or `unclear`, plus the files a fix would touch.
  An item carrying a `reviewedSha` is diffed against the branch first, so a stale
  comment is answered from the log rather than re-derived from the code.
- **Baseline** — checks the branch already builds and lints before anything is
  changed, and that the test database is up if integration tests are in scope. If
  it isn't green the run stops immediately: breakage that was already there would
  otherwise be blamed on an innocent fix.
- **Plan** — one agent adds ordering edges (signature before call sites) and
  folds duplicate comments together. Two fixes sharing a file are separately
  prevented from running at the same time; that's exclusion, not ordering, and it
  doesn't imply either order.
- **Apply** — level by level. Everything in a level has a disjoint file set, so
  those edits run concurrently. Edit agents don't build, test, or run git.
- **Verify** — once per level, over the tests that level touched.
- **Repair** — a failing level gets up to two attributed rounds. If a failure
  can't be pinned on a specific fix, a dedicated attribution pass tries again
  from the diff; if that's still not confident, **nothing is reverted** — the run
  stops with the work left in the tree for you.
- **Commit** — one commit per issue, staging only that issue's files, pre-commit
  hook running. Never `--no-verify`.
- **Final check** — the full suite once, after every level has landed. Per-level
  verification only ever ran the tests each level touched, so this is the first
  chance an untouched test gets to fail. This is what the push decision rests on.
- **Push** — the workflow pushes, not you. It has to happen before the replies:
  every answer to a fixed finding links to the commit that fixed it, and an
  unpushed sha 404s. Skipped when the run halted, the final check is red, nothing
  was committed, or `push: false` — and then any answer carrying a commit link is
  held rather than posted with a dead link.
- **Reply** — after the fixing, not alongside it, and the split is by who's on
  the other end. Each post is read back before the agent calls it done, then the
  automated thread is resolved.

An automated thread is resolved once its answer is posted — the finding has been
dealt with and nobody is waiting on it. A thread a person started is never
resolved, however thoroughly it was answered; that one is theirs to close. This
matches the repo convention, so check the project's own git docs before assuming
it: a repo that says otherwise wins over this line.

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

The explanation is written by the agent that made the change, at the moment it
still has the whole picture, so it describes what actually landed rather than
what was planned. Each post reads the thread first, so a retry can't double-post.

### Nothing aimed at a person is ever posted

Human comments get the same analysis and the same drafts, but they come back to
you instead. The workflow returns `humanReview` — a complete Markdown document.
**Write it to your scratchpad directory** under `humanReview.filename` and give
the user the path. Per item it carries:

- the link to the comment thread
- the permalink to the commit that answers it, if there is one
- the outcome, and a quote of what they said
- a draft reply in a fenced block, ready to copy

That includes items that were *fixed* — those are the ones with no draft under
the old design, and they're exactly the ones the user has to answer by hand.

With no PR in scope everything comes back as drafts and `postingBlocked` says why.

Two things to be aware of and honest about. Verification is per level, so with
more than one fix in a level each commit is green *in combination with its
siblings*, not individually — the pre-commit hook and the final check are what
cover the rest. And several comments on one file are necessarily serialized, one
level each, which on a big monorepo can be slower than fixing them by hand.

## Push

The workflow owns this. Pass `push: false` if the user asked you not to, and
expect the automated answers to be held in that case — they'd carry dead commit
links otherwise.

Read `pushed` when it returns. If it didn't push, say why: `skipped` names the
reason, and `error` carries the pre-push hook's output verbatim when a hook
refused. Don't push over the top of a refusal — whatever the hook caught needs
looking at first.

## Summary

The workflow returns `fixed`, `alreadyFixed`, `disagreed`, `unclear`, `blocked`,
`duplicates`, `untriaged`, `heldReplies`, `humanReview`, `replies`, `pushed`,
`items`, `treeDirty`, `halted`, `baseline`, `finalCheck`, `strayPaths`,
`postingBlocked` and `schedule`.

First, **write `humanReview.markdown` to your scratchpad** under
`humanReview.filename`. That file is the deliverable; the summary points at it.

Then report on every item — an id in none of those buckets is itself worth
reporting.

```
Fixed (N) — one commit each, answered on their threads:
  c1. <issue summary> — <short sha>

Already fixed on the branch (N):
  c2. <issue summary> — landed in <sha>

Refuted (N):
  c3. <issue summary> — <one-line reason>

Not fixed (N):
  c4. <issue summary> — <reverted after verification failed: X | left in tree: Y>

Answered on the PR: N automated threads, N resolved. Nothing was sent to a person.

Waiting on you — N human items:
  <absolute path to the written file>
  c26 refuted · c68 fixed in 596fcddbe · …

Full suite: <green | RED: what failed>
Push: <pushed e9495317b..27cbdf66f | not pushed: reason>
```

Keep `alreadyFixed` out of "Refuted". They're a different answer — the comment
was right and the work is done — and burying them there misrepresents both
numbers.

Don't re-quote the human drafts in the summary. They're in the file, in full,
and repeating them here is the thing the file exists to avoid. A one-line index
of what's waiting is enough.

Then `git diff <baseSha>..HEAD --stat` for the cumulative picture.

Seven things to surface rather than bury, because they mean something is unfinished:

- **a reply with `posted: true` but `bodyVerified` unset or false** — the answer
  may be sitting on the thread as a literal file path instead of its text. Read
  the thread and check. This is what `-f body=@…` used to do, silently, because
  the API call succeeds either way.

- **`halted`** — the run stopped early. Say where and why, and that later items
  were never attempted.
- **`finalCheck.green === false`** — the branch is red at the tip even though the
  commits landed. Nothing was pushed and nothing was answered.
- **`pushed.pushed === false`** with commits in `fixed` — the work is committed
  locally and invisible on the PR, and the automated answers are held with it.
  Say what stopped it.
- **`treeDirty`** — uncommitted changes beyond what was already there. List the
  files. This is deliberate (the workflow does not throw work away when it can't
  attribute a failure), but it needs a decision from the user.
- **`baseline.green === false`** — the branch was already broken before any fix.
  Nothing was attempted; that's the thing to fix first.
- **`strayPaths`** — an agent reported a file outside `cwd`, which means it was
  working in a different checkout. Nothing downstream can be trusted; say so.
