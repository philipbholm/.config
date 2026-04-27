---
name: code-review
description: Comprehensive code review for diffs, branches, and pull requests. Covers security, authorization, code quality, silent failures, tests, and type design. Uses Codex-native parallel reviewers only when the user explicitly asks for delegation or parallel review; otherwise performs the same review in a single local pass.
metadata:
  short-description: Multi-lens code review for Codex
---

**CRITICAL: This is a read-only review. Do not modify source code, tests, generated files, or migrations.**

You are the review lead. Your job is to determine the review scope, gather the right project rules, run a rigorous review, and write a unified review document to disk.

## Review Scope

Use one of these scopes based on the user request:

- `diff`: staged and unstaged local changes
- `branch`: all changes on a branch compared to the default remote branch using merge-base
- `pr <number>`: a GitHub pull request

If the user does not specify a scope, default to `diff`.

## Codex Compatibility Rules

- Read repository guidance before reviewing. Check repo-root `AGENTS.md` first, then `CLAUDE.local.md` if present.
- For the Ledidi monorepo, also read the relevant docs under `/Users/philip/.config/dev/context/ledidi-monorepo/`.
- This skill includes bundled Ledidi reviewer references under `references/`. Load the relevant ones when reviewing Ledidi code or when you want the more opinionated reviewer heuristics from the original Claude agents.
- Only use Codex subagents when the user explicitly asks for delegation, subagents, or parallel review.
- When subagents are allowed, use read-only `explorer` agents. They should return findings in their final message. Do not make them write files or edit code.
- If subagents are not explicitly requested, perform the full review locally in one pass.
- Only report genuine issues. Avoid speculative or low-confidence findings.

## Workflow

### 1. Determine the diff

First resolve the default branch:

```bash
git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##'
```

If that returns nothing, fall back to `master`, then `main`.

Fetch the base branch before comparing:

```bash
git fetch origin <default-branch>
```

Use these scope-specific commands:

**For `diff`:**

```bash
git diff
git diff --cached
```

**For `branch`:**

```bash
git diff "$(git merge-base origin/<default-branch> HEAD)"
git diff --name-only "$(git merge-base origin/<default-branch> HEAD)"
```

**For `pr <number>`:**

```bash
gh pr diff <number>
gh pr diff <number> --name-only
```

Read the full source files for changed areas as needed for context.

### 2. Load project rules

Read the most specific project guidance that exists:

- repo-root `AGENTS.md`
- repo-root `CLAUDE.local.md`

For Ledidi repos, use these files as the authoritative supplements when relevant:

- `/Users/philip/.config/dev/context/ledidi-monorepo/AGENTS.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/CLAUDE.local.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/testing.md`

This skill also bundles reviewer-specific Ledidi guidance:

- `references/ledidi-security-auth-reviewer.md`
- `references/ledidi-code-reviewer.md`
- `references/ledidi-test-reviewer.md`

Load them selectively:

- Always load `references/ledidi-security-auth-reviewer.md` and `references/ledidi-code-reviewer.md` for Ledidi reviews.
- Load `references/ledidi-test-reviewer.md` when the diff changes tests, authorization, data mutations, or non-trivial business logic.

Use project-specific rules over generic rules in this skill.

### 3. Choose execution mode

**Single-agent mode:** default. Review all lenses locally.

**Parallel mode:** only if the user explicitly asked for delegation, subagents, or parallel review.

In parallel mode:

- Spawn `security-auth` as an `explorer` agent. Always run it.
- Spawn `code-quality` as an `explorer` agent. Always run it.
- Spawn `test-coverage` as an `explorer` agent only when the diff adds non-trivial functionality or touches tests.
- Pass each agent the exact diff command and changed file list.
- In each agent prompt, include the relevant bundled reference file path and instruct the agent to read it before reviewing.
- Tell every agent this is a read-only review and that it must not edit files.
- Have each agent return markdown findings directly in its final message.
- While agents run, do non-overlapping checks locally. Good side checks:
  - whether generated types or clients likely need regeneration
  - whether schema or migration changes look reversible and complete
  - whether changed files indicate missing docs or config updates
- Wait once when you actually need the reviewer outputs for synthesis.

### 4. Reviewer responsibilities

Use these responsibilities in both single-agent and parallel mode.

In single-agent mode, use the corresponding bundled reference files as extra heuristics instead of trying to remember them from the Claude setup.

**`security-auth`**

- Authorization bypasses and missing permission checks
- Injection, XSS, unsafe interpolation, raw query misuse
- Data exposure, insecure token handling, sensitive logging
- Client-side security anti-patterns

**`code-quality`**

- Bugs, incorrect conditions, state and lifecycle mistakes
- Silent failures, swallowed errors, fire-and-forget async
- Architecture violations
- Performance issues, unnecessary complexity, stale comments
- Naming, type-shape, and maintainability issues that materially matter

**`test-coverage`**

- Missing authorization tests for allowed and denied paths
- Missing tests for new business logic, error paths, and edge cases
- Weak tests that assert implementation details instead of behavior
- Missing migration, schema, or integration coverage where relevant

Each reviewer should return:

- only real findings
- severity
- file:line references
- impact and suggested fix
- `No issues found.` if there are no findings

### 5. Review lenses

Apply these lenses in order:

1. Authorization
2. Security
3. Code quality and logic
4. Silent failures
5. Simplification opportunities
6. Comments and documentation drift
7. Test coverage
8. Type design

### 6. Standards to enforce

Backend (`services/`):

- Handler -> Application -> Adapter layering
- dependency injection via `Ports`, not singleton imports
- typed application errors with subcodes
- one GraphQL operation per `.graphql` file
- Zod for unknown or external input
- integration tests for new functionality
- no TypeScript enums when project conventions use string literals or const maps

Frontend (`apps/registries-frontend/`, `apps/main-frontend/`):

- minimize unnecessary `useEffect`
- prefer query objects over destructuring query results
- descriptive function names based on intent
- route/id hook conventions and route map conventions
- confirmation flows for destructive actions
- `clsx` plus `tailwind-merge` for class composition where that is the project pattern
- translation keys for user-visible text when the app is localized

General:

- descriptive names
- comments explain why, not how
- remove dead compatibility code instead of keeping it around
- avoid weak typing, `any`, and gratuitous type assertions

### 7. Write the review file (MANDATORY)

**You MUST save the review to `/Users/philip/vaults/main/dev/reviews/`. This is not optional. Do not write the review to the current working directory, the worktree, `/tmp/`, or anywhere else. Do not print the review to the chat instead of saving it.**

Compute the output path:

1. Get the branch name with `git branch --show-current`.
2. Sanitize it for filenames by replacing `/` with `-`.
3. Generate a timestamp with `date +%Y%m%d-%H%M%S`.
4. Ensure the directory exists: `mkdir -p /Users/philip/vaults/main/dev/reviews/`.
5. Build the absolute path: `/Users/philip/vaults/main/dev/reviews/<safe-branch>-codex-<timestamp>.md`.
6. Never overwrite an existing review file — if the path already exists, regenerate the timestamp.

If `mkdir -p` fails, stop and report the failure to the user. Do not invent an alternate location.

Write a single unified markdown review to that absolute path. Skip empty sections.

```markdown
# Code Review

## Summary

[1-2 sentence overview of what changed and overall assessment]

## Issues Found

### Critical
- [Issue]: [file:line] - [impact and fix]

### Major
- [Issue]: [file:line] - [impact and fix]

### Minor
- [Issue]: [file:line] - [impact and fix]

### Nitpick
- [Issue]: [file:line] - [optional improvement]

## Test Coverage
[Assessment]

## Verdict: [Approve | Request changes | Comment]
```

### 8. Final output

Output the **full absolute path** to the saved review, starting from `/`, so the user can click it to open it.

- Correct: `/Users/philip/vaults/main/dev/reviews/<safe-branch>-codex-<timestamp>.md`
- Wrong: `<safe-branch>-codex-<timestamp>.md` or `reviews/<safe-branch>-codex-<timestamp>.md`

Do not summarize the review contents in the chat — the saved file is the deliverable.
