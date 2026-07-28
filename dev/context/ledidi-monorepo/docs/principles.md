# Engineering Principles

Standing judgment calls for this codebase. Where a specific rule elsewhere in
`docs/` conflicts with something here, the specific rule wins.

## Quality Bar

Shipping an incomplete feature is fine — put it behind a feature flag. Three
things don't bend regardless of how unfinished the feature is:

1. Security
2. Test coverage and test quality
3. Code review before anything reaches master

## Debugging

Start with the logs of the running Docker containers. They describe what
actually happened; anything before reading them is a guess.

Carry the investigation to a root cause and fix that, not the symptom. Report
the full context of what you found — what the user was doing, what the system
did, and whether it is genuinely a bug. Whether an error is noise is a
conclusion, not a starting assumption: it needs the same context as any other
verdict.

When a build, tool, or test fails and master is green, the cause is in the
current branch. Treat CI and local test failures as yours to fix and stay on
them until they pass, including the ones that look unrelated to your change.

When the code contradicts something I've told you, say so and show what you
found rather than adopting my version.

## Maintainability

**Boy scout rule.** Leave each file a little better than you found it — a
clearer name, a dead branch removed. Larger refactors are their own PR.

**No broken windows.** Anti-patterns, shortcuts, flaky tests, and recurring
transient errors compound, because generated code imitates whatever is already
there. Fixing them as they appear is what keeps that from setting the pattern
for everything written next.

**Prefer subtraction.** The better fix usually removes lines rather than adding
them.

**Strengthen the harness after a mistake.** When something breaks, ask what
check, type, lint rule, or piece of tooling would have caught it, and add that
too.

## Where to Spend Effort

Frontend code quality is not where the leverage is anymore — thorough test and
Storybook coverage carries most of it, particularly for quirky behaviour that
regresses easily. Follow the frontend conventions in `docs/code-style.md`, but
spend the extra polish on parts of the app that are buggy, hard to maintain, or
otherwise need the attention. Backend and shared packages hold to the full bar.

## Error Handling

Errors carry application flow here. An error used for expected flow gets caught
and handled somewhere.

Handle the error types you catch explicitly, then rethrow what you did not
handle. A catch block that swallows everything and returns is the pattern to
avoid.

## UX

Disable an element rather than removing it. When a control simply vanishes, the
user can't tell whether they lack permission, something is misconfigured, or
it's a bug.

## Writing Code and Comments

Spell words out. Don't introduce acronyms or abbreviations of your own.

No links to GitHub issues (`#2858`) in source code.

## AI-Generated Content

Anything you write outside the codebase — GitHub comments, reviews, summaries —
is marked as AI-generated.
