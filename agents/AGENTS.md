# AGENTS.md

Global rules. These apply in every repo.

## How to write to me

Write for a colleague who knows the codebase but was not in this session.
English is my second language. If I read a sentence twice, it failed.

Lead with the outcome. The first sentence says what happened or what you found.

Keep it short by leaving things out, not by squeezing the words. Drop detail
that does not change what I do next. What stays gets written in full sentences.

Name the thing. Not "the former", not a bare "it", not "one ... the other".
Say the file, the value, the variable.

Show it before you explain it. Four named rows beat a paragraph of theory.

Use a word this repo already uses. Do not invent one. Do not borrow a word that
already means something else here.

Every reference must resolve. If I cannot grep it or click it, say the thing
instead of pointing at it.

Say how sure you are when you are not sure, in its own short sentence.
Leave the sentence out when you are sure.

This covers everything I read: chat, status summaries, reports of work you
already did, commit messages, PR and issue text, Slack, README files, test
names, and strings a user sees.

### Examples

**Weak:** The refactor consolidates duplicated validation logic across the handler
layer, thereby reducing the surface area for divergent behaviour.

**Better:** Three handlers each had their own copy of the same validation. Now they
share one function.

**Weak:** A table shows the prefix that ends at its own level, and nothing below it.

**Better:** A table carries the columns down to its own level, and stops there. A
patientEventEntry table has the first three; the fourth is absent, not null.

**Weak:** Two things worth knowing, neither a blocker.

**Better:** One problem you must know about. The rest of the stack uses this field,
so those branches will not compile after you restack.

## Code comments

Write code without comments. Add or rewrite a comment only when I ask for that
comment. This rule beats a repository's comment conventions and any harness
default about matching comment density.

Carry meaning in names instead: a better variable, function or test name.
When the code needs a fact it cannot show, such as a hidden constraint or a
workaround, tell me in your report and let me decide on a comment.

When your change makes an existing comment false, delete that comment and say
so in your report.

When I ask for a comment, it says its thing in full. Use enough words to make
it understandable on its own.

Say what is true. Not what a future change would do, not what a rejected
alternative would have done, not why your change is correct.
Do not refer to the current task or a GitHub issue.

## Requests

Requests to explain, evaluate, compare, or show what a change would look like
call for inspection and recommendations. Edit only when the conversation also
authorizes implementation. Agreement on a design question settles that question;
it does not by itself authorize building the feature. Continue already-authorized
work without asking for permission again.

For a factual code question, inspect the named code and relevant callers. Load
review workflows when assessing correctness, design, or coverage; explaining a
line does not itself require a review or test run. Execute a check only when it
resolves a specific uncertainty.

Reuse applicable instructions already read in this session. Read them again
when their files change, the scope changes, or their contents are no longer
available in context.

## Subagents

My Mac has resources for one working session at a time. Use subagents to read
and search, and have them send back a summary. Make edits and run tests and
builds in the main session, one at a time. Start other sessions only when I ask
for one.

Claude Code enforces part of this: `claude/settings.json` denies the
`general-purpose` and `claude` agent types and the `Workflow` tool. Codex and
Cursor Agent have only this rule.

## Commits and pull requests

Before creating or amending a commit, drafting a commit message, or reviewing
commit-message style, load `write-commit`.
Before planning PR scope or writing or reviewing a PR title or description,
load `write-pr`.

Commit completed changes as part of finishing an implementation task, after
the relevant checks pass. Make focused commits at coherent stopping points
without waiting for me to request a commit. Include only changes belonging
to the task.

Follow the repository's branch rules.

Push when I request it, when an authorized workflow requires it, or when
repository instructions require automatic pushing. An existing pull request
alone is not a reason to push.

Explicit requests to leave changes uncommitted or unpushed override these
defaults.

Keep every pull request in draft until I explicitly ask you to mark that pull
request ready for review. A finished implementation, resolved review findings,
or green checks mean the draft is ready for me; they do not change its state.
A repository whose own instructions say to open pull requests ready for review
overrides this rule; follow the repository there.

If a skill includes a ready-for-review transition, report readiness and leave
the pull request in draft.

## Worktrees

These rules apply wherever the repository names no other worktree location or
tool. Ledidi checkouts follow their `worktree` and `cleanup-dev` skills.

### Create or enter

Create worktrees with `git worktree add` at `<repo>/.worktrees/<name>`. The
global git ignore file already excludes `.worktrees/`.

1. Inspect `git status` and `git worktree list`. Uncommitted changes in the
   current checkout may be the work I mean; ask before moving them. When the
   branch is already checked out in a worktree, continue there.
2. Use one short kebab-case name for both the branch and the directory, with
   no `feat/` or `worktree-` prefix. Ask when the directory already exists.
3. For new work, run `git fetch origin` and branch from the remote default
   branch; the current `HEAD` may be unrelated. An existing branch keeps its
   commits.

Report the worktree name, path and branch after creating it.

Keep one writer per branch. Before writing in an existing checkout, look for
another session working there. Before committing, recheck `HEAD` and inspect
any commits another session added.

### Clean up

A worktree is removable when all of these hold:

- Its work has landed on the default branch: a merged pull request whose
  final head commit equals the branch tip, or a branch tip that is an ancestor
  of the default branch. A closed pull request has not landed. A local squash
  merge leaves no such evidence, so that worktree needs my approval.
- It has no other commits, no uncommitted changes, and no unique untracked or
  ignored files such as `.scratch/`, notes, exports or local data.
  Dependencies and build output do not count.
- It is not the main checkout, not locked, and not in use by another session.

When a task of yours lands a branch, remove its worktree once it is removable,
and say which one you removed. Green checks or the end of a session alone do
not make a worktree removable.

When I ask for cleanup, inventory every registered worktree, including those
the harnesses created under `.claude/worktrees/` and `~/.codex/worktrees/`.
Remove the removable ones. List the rest as numbered rows with your
recommendation and what deletion would lose, then remove only the numbers I
reply with.

Remove a worktree with `git worktree remove <path>` from the main checkout,
without `--force`, and keep its branch.

## Agent skills

### Issue tracker

Repos under `~/work/` keep their agent issue tracker inside the repo's ignored
`.scratch` directory, at:

    <repo>/.scratch/agents/issue-tracker.md

Read that file first, before any `/wayfinder`, `/triage`, `/to-spec` or
`/to-tickets` work, or when `/code-review` needs an originating issue. It is
the authority on where maps, tickets and specs live. Its sibling
`agents/triage-labels.md` holds the triage label vocabulary.

Read `<repo>/.scratch/agents/domain.md` before an engineering skill explores a
repo. It defines where the repo's `CONTEXT.md` and ADRs live and how to consume
them.

Maps, tickets and specs sit beside the `agents/` directory, one directory per
effort:

    <repo>/.scratch/<effort>/

The directory is inside the working tree but gitignored. Nothing there is
committed or shared.

**GitHub Issues are not the agent tracker for these repos.** Old agent tickets
can still be there, closed. Do not read them as the tracker, and do not create
new ones. Pull requests are different — they stay on GitHub as normal.

If `<repo>/.scratch/` does not exist, the repo has no tracker yet.
Ask me before you make one, or run `/setup-matt-pocock-skills` when I request
the complete tracker, label and domain setup.
