# Work pull requests

## Scope and reviewer context

- Keep one concern per PR. Separate prerequisite fixes, formatting, security,
  and observability work when they can land independently.
- Aim for fewer than 25 files and 1,500 changed lines. More than 40 files or
  3,000 changed lines requires a concrete reason; first look for a coherent
  split.
- Explain unexpected generated files, lockfile changes, migrations, copied
  patterns, and configuration changes.
- Check every behavior and verification claim against the final diff and
  completed checks. Use the migration names and API shapes that actually ship;
  remove claims left over from an abandoned implementation.

## Ledidi monorepo

Use a gitmoji title. Use `## Why` and `## What` as the only body sections.
`## Why` explains the problem and the outcome. `## What` explains the change.
Quote new user-facing strings when the wording matters to review.
Include material migration, compatibility, privacy, and rollout risks under
`## What`, together with the relevant verification. Follow the repository's
current risk-classification requirements without adding headings requested
only by an older automated review.
