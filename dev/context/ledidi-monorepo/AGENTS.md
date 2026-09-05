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

Use `dev --help` to discover development commands and their scope.

Load the matching shared skill before acting:

| Request | Skill |
|---------|-------|
| Create or open a pull request | `create-pr` |
| Run checks, investigate check or hook failures, commit, or push | `verify-change` |
| Change or review code | `coding-standards` |
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
| "save to vault" | Write a markdown file to `/Users/philip/vaults/work/dev` |

Committing and pushing don't need approval.

### Service setup

Creating or entering a worktree, rebasing, committing, and pushing do not by
themselves require dependency setup or service startup.

### Datadog

Open a Datadog link and confirm it returns results before putting it in a
comment, PR, or report. These URLs are easy to construct plausibly and wrong; a
link showing nothing costs more than no link.
