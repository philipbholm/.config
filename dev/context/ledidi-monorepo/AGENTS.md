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
say otherwise. Include affected consumers when inspecting, regenerating,
fixing compatibility, and verifying a shared change. Unrelated product changes
in sibling apps need their own task.

### Terminology

- **Ledidi Trials** is the product; **study/studies** names its domain objects
  and backend service. Trials uses the shell app as its frontend.
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

## Read the applicable context

Before exploring code, read `.scratch/agents/domain.md` and follow its domain
documentation pointers when present. Before editing or reviewing an affected
path, read the `AGENTS.md` and `CLAUDE.md` files along that path, including their
conditional references. These filenames carry shared project guidance for
Claude Code, Codex, and Cursor; read a referenced local skill by file path when
the harness does not discover it automatically.

Load `coding-standards` before implementation or review, select its references
by behavior and affected consumers, and revisit them when scope changes. Before
handing off, check the final diff against those rules and the selected checks.

For setup commands or workflow instructions in nested context, read
[Context precedence](/Users/philip/.config/dev/context/ledidi-monorepo/context-precedence.md).
It identifies legacy instructions superseded by the shared workflows.

## Workflow skills

Use `dev --help` to discover development commands and their scope.
Use `dev context show` to inspect the current checkout and instruction paths,
and `dev context check` to detect stale context or broken skill links.
Use `dev session search --help` to find earlier Claude Code or Codex conversations
for this repository.

Load the matching shared skill before acting:

| Request | Skill |
|---------|-------|
| Create or open a pull request | `create-pr` |
| Make a PR green; keep fixing and monitoring PR checks | `finish-pr` |
| Restack dependent PRs or change a PR's base branch | `restack-pr` |
| Assess review feedback or implement its fixes | `address-feedback` |
| Preview or deploy a registries production release | `registry-release` |
| Clean up stale worktrees, dev stacks, or leftover Docker resources | `cleanup-dev` |
| Run checks, investigate check or hook failures, commit, or push | `verify-change` |
| Change or review code | `coding-standards` |
| Create, enter, or remove a worktree | `worktree` |
| Prepare workspace dependencies; start, operate, or diagnose the development stack; verify in a browser | `dev-stack` |
| Seed a demo registry | `seed-registry` |

### Commands

Use the maintained `package.json` script for generation, migrations, builds,
and tests; pass supported arguments through that script. Read the script in
the affected workspace instead of copying a tool command from old context.
Use `dev` commands for worktrees and local stacks. When no package script
exists for an operation, follow the owning workflow's command.

### User Instructions

| When user says | What it means |
|----------------|---------------|
| "save to vault" | Write a markdown file to `/Users/philip/vaults/work/dev` |

Committing and pushing don't need approval.

### Service setup

Creating or entering a worktree, rebasing, committing, and pushing do not by
themselves require dependency setup or service startup.

### Feature flags

When a feature is missing despite an enabled flag, read
[Feature-flag diagnosis](/Users/philip/.config/dev/context/ledidi-monorepo/feature-flags.md)
before changing code.

### Datadog

Open a Datadog link and confirm it returns results before putting it in a
comment, PR, or report. These URLs are easy to construct plausibly and wrong; a
link showing nothing costs more than no link.
