# AGENTS.md

Guidance for agents working in the Ledidi monorepo.

## Project Overview

Medical registry platform. Each service/app has its own `package.json`.

| Path | Description |
|------|-------------|
| `apps/registries-frontend/` | Registries frontend (React 19 + Vite) |
| `services/registries/` | Registries backend (PostgreSQL, GraphQL + gRPC) |
| `services/codelist/` | Code list service (PostgreSQL, gRPC only) |
| `packages/` | Shared libraries (@ledidi-as scope) |

Default focus is `services/registries` and `apps/registries-frontend` unless I
say otherwise. The sibling apps — `analysis-room-frontend`, `legacy-frontend`,
`patient-frontend`, `shell` — are in scope only when I name one.

### Terminology

- **Trials** and **studies** are the same thing in this repo, interchangeable.
  Studies use the shell app as their frontend.
- **John** is the AI agent that analyses tenders for Ledidi.

## Ports (Worktree-Specific)

This is one of many parallel worktrees, each with its own isolated Docker stack
and unique ports.

| Service | URL |
|---------|-----|
| Frontend | http://localhost:{{FRONTEND_PORT}}/en/registries |
| Registries (GraphQL) | http://localhost:{{REGISTRIES_PORT}}/graphql |
| Registries (gRPC) | localhost:{{REGISTRIES_GRPC_PORT}} |
| Codelist (gRPC) | localhost:{{CODELIST_GRPC_PORT}} |
| PostgreSQL | localhost:{{POSTGRES_PORT}} |

These ports belong to this worktree alone, and they are correct as listed. When
one doesn't respond, the Docker stack is what needs attention — the standard
ports (5432, 3000, 4000) belong to other stacks, and editing hardcoded URLs, env
files, or configs to reach a service breaks the worktree instead of fixing it.

## Workflow skills

Load the matching shared skill before acting:

| Request | Skill |
|---------|-------|
| Create or open a pull request | `create-pr` |
| Create, enter, or remove a worktree | `worktree` |
| Prepare workspace dependencies; start, operate, or diagnose the development stack; verify in a browser | `dev-stack` |
| Seed a demo registry | `seed-registry` |

### Commands

**Always use package.json scripts.** Never run tools directly:

```bash
# Correct
npm run generate
npm run migrate
npm run test

# Wrong
npx prisma generate
npx prisma migrate dev
npx jest
```

### User Instructions

| When user says | What it means |
|----------------|---------------|
| "red/green TDD" | Run both unit tests and relevant E2E tests |
| "commit" | Pre-commit hook must pass |
| "push" | Pre-push hook must pass |
| "save to vault" | Write a markdown file to `/Users/philip/vaults/work/dev` |

Committing and pushing don't need approval.

### Rebased pushes

After a rebase or another history rewrite, Lefthook can select a workspace
changed only by incoming base-branch commits. Confirm that the workspace is
absent from `git diff --name-only origin/master...HEAD`. If that workspace is
the only reason pre-push fails and the branch's own checks passed, use
`git push --force-with-lease --no-verify`. The pull request checks cover the
incoming changes.

### Failing Builds and Tests

Fix pre-existing lint or type errors first and commit that fix before starting
new work.

While master is green, a failing build, tool, or test comes from this branch.
Those are yours to fix and stay on, including the ones that look unrelated to
what you changed.

### Datadog

Open a Datadog link and confirm it returns results before putting it in a
comment, PR, or report. These URLs are easy to construct plausibly and wrong; a
link showing nothing costs more than no link.

## Coding Standards

Read
[CODING_STANDARDS.md](/Users/philip/.config/dev/context/CODING_STANDARDS.md)
before changing or reviewing code. The file is the shared authority for
engineering, security, privacy, reliability, and testing rules. This repository
context adds operational detail but does not duplicate those rules.
