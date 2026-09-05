# Work pull requests

## Scope and reviewer context

- Keep one concern per PR. Separate prerequisite fixes, formatting, security,
  and observability work when they can land independently.
- Aim for fewer than 25 files and 1,500 changed lines. More than 40 files or
  3,000 changed lines requires a concrete reason; first look for a coherent
  split.
- Explain unexpected generated files, lockfile changes, migrations, copied
  patterns, and configuration changes.

## Ledidi monorepo

Use a gitmoji title. Use `## Why` and `## What` as the only body sections.
`## Why` explains the problem and the outcome. `## What` explains the change.
Quote new user-facing strings when the wording matters to review.
