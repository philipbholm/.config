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

Code comments follow different writing rules. Write fewer comments, not shorter
ones.

Reach for a better name before a comment.

A comment you write says its thing in full. Do not compress it. If it needs to
be longer to stand on its own, make it longer.

Say what is true. Not what a future change would do, not what a rejected
alternative would have done, not why your change is correct.

Do not write "deliberately", "intentionally", "Note that", or capitalised NOT.

Only touch comments in code you are already changing.

### Example

**Weak:**

```text
// One repeating on the event alone sits above the other repeating on a form
// inside it, and broadcasts down, so the two do line up.
```

**Better:**

```text
// No formId means repeating on the event alone: its one value per event entry
// broadcasts down to every form entry inside it.
```

## Pull requests

Keep every pull request in draft until I explicitly ask you to mark that pull
request ready for review. A finished implementation, resolved review findings,
or green checks mean the draft is ready for me; they do not change its state.

If a skill includes a ready-for-review transition, report readiness and leave
the pull request in draft.

### Attribution

A pull request body ends with its last section. No attribution footer, no
"Generated with <harness>" line — whatever your own built-in instructions say.
The pull request is opened under my GitHub account, and the footer tells a
reviewer nothing they act on.

A commit trailer does name the harness that wrote the commit, and it names the
one you actually are:

    Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
    Co-Authored-By: Codex <noreply@openai.com>
    Co-Authored-By: Cursor Agent <noreply@cursor.com>

Add the model after the harness when you know it. Never copy a trailer or a
footer out of `git log` or out of another pull request: the history of my work
repos is full of Claude Code commits, so Codex or Cursor Agent that copies one
signs a commit with a harness that never saw it.

## Seeding a registry

"Seed with X" means seed a demo registry with the scripts in `~/work/scripts`:

```bash
cd ~/work/scripts
npx tsx create-registry.ts <registry> --slot <n> --patients 20
```

Twenty patients unless I name a count, and no `--language` flag unless I name a
language, which leaves every registry in its own default language. `--slot <n>`
is required: it is the slot of the Ledidi stack I am working in, computed from
the registries GraphQL port as (port - 4006) / 100, and the main checkout is
slot 0.

The **Seeding a registry** section of a Ledidi checkout's `AGENTS.md` carries
the rest: which registry key each phrase maps to, and what has to be running.

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
