---
name: coding-standards
description: Apply work-repository coding standards before changing or reviewing code. Load the common baseline and only the references relevant to the change and affected consumers.
---

# Apply coding standards

These are the shared engineering and review standards for work repositories.
They are authoritative; repository context may add stricter rules or explain
how a rule applies.

Before reviewing code, read
[Review quality](/Users/philip/.config/skills/code-review/references/review-quality.md).

## Select the references

Apply the baseline below to every code change. Before changing code or
performing a review pass, read every reference whose condition matches the
behavior, inputs, or affected consumers, not just the edited paths. Include
test-only changes and revisit the selection when the scope changes. Inspect
callers and data flow before excluding a topic whose relevance is unclear.

| Condition | Reference |
|-----------|-----------|
| TypeScript types, schemas, validation, or configuration parsing | [TypeScript and validation](references/typescript.md) |
| Services, handlers, use cases, APIs, events, or persistence | [Backend and architecture](references/backend.md) |
| UI components, hooks, forms, translations, styles, accessibility, or client state | [Frontend](references/frontend.md) |
| Authorization, tenant scope, sensitive data, audit, deletion, trust boundaries, configuration, dependencies, or external data sharing | [Security and privacy](references/security-and-privacy.md) |
| Application behavior, data formats, mutations, failures, concurrency, migrations, compatibility, or shutdown | [Correctness and reliability](references/correctness-and-reliability.md) |
| Application behavior or test changes, including assessing missing coverage | [Testing](references/testing.md) |
| CI, deployment, infrastructure, scripts, or source-processing services | [Infrastructure](references/infrastructure.md) |

Before planning PR scope or reviewing PR titles and descriptions, load
`write-pr`. Before reviewing commit-message style, load `write-commit`.

## Engineering baseline

- Security, privacy, test coverage, and test quality do not bend for incomplete
  features. Put incomplete work behind a feature flag.
- Fix the root cause and strengthen the test, type, lint rule, or harness that
  could have caught the failure. Do not normalize flaky tests, recurring errors,
  or known anti-patterns as background noise.

## Security and data baseline

- Enforce authorization on the server before any protected data access or side
  effect. Frontend visibility and masking are usability controls, not security.
- Do not put patient data, credentials, tokens, or secrets in application logs,
  error messages, analytics, tracing, metrics labels, URLs, or source maps.
- Secrets stay outside source, generated artifacts, logs, client bundles, and
  test fixtures.
- Validate domain invariants in the application layer so every transport and
  ingestion path receives the same protection.

## Design baseline

Before recommending a use-case shape, name, migration, test helper, or UI
interaction, inspect two or three comparable examples in the affected service
when available. Show the closest example and explain any proposed departure.
If no comparable example exists, say so. Compare with another service, such as
studies, when the task calls for that comparison.

- Prefer concrete code until at least two real cases establish a shared shape.
  Remove middle layers that only rename or delegate a call.
- Place behavior and data with the domain concept that owns them. Keep display
  formatting and presentation sorting in the frontend.

## Code style and organization

- Choose descriptive domain names. Avoid generic `data`, `info`, and `item`, and
  spell words out instead of inventing abbreviations.
- Name functions for their result or action: `get` guarantees a result, `find`
  may return none, `resolve` transforms, and `check` answers a boolean.
- Name conversion functions `sourceToTarget`. Boolean props start with `is` or
  `has`.
- Prefer early returns and a flat main path. Extract a branch when its body hides
  the high-level flow.
- New general files use kebab-case. Hooks and GraphQL operations follow their
  established repository naming conventions.
- Use the repository path alias for deep imports. Import source modules directly
  and do not create barrel files for application code.
- Remove dead code, unused dependencies, abandoned files, debug output, and
  scaffolding before review.
- Do not add a helper, interface, wrapper, dependency, or abstraction for one
  hypothetical consumer.
- Follow nearby conventions for the order of declarations within a file.
- Inline a props type unless it is shared, semantically meaningful, or too large
  to read at the function boundary.
- A file that becomes difficult to navigate should split along cohesive
  responsibilities, not an arbitrary line count.
