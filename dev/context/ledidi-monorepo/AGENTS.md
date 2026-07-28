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
say otherwise. **Never touch `apps/main-frontend/`.**

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

## Workflow

### Worktrees

Worktrees live at `<repo>/.claude/worktrees/<name>` — nowhere else.

- **New branch** → `EnterWorktree` with an **explicit `name`**, then run
  `setup-stack` inside it.
- **Existing branch** → `git worktree add .claude/worktrees/<name> <branch>`,
  then `EnterWorktree path:<path>`, then `setup-stack`.
- **Never omit the name.** A generated name becomes the Docker stack ID, which
  produces unpredictable compose project names and orphaned slot files.
- `setup-stack` installs dependencies and generates types. It starts no
  containers.
- **The Docker stack is opt-in.** Run `dev up` only when you need to exercise
  the app in a browser. Then re-run `sync-context` to get the port table.
- **Teardown** → `wt-down` from inside the worktree. Not
  `ExitWorktree action:remove`, which deletes the branch and leaves the Docker
  stack orphaned.

### Environment

- **Use `dev` instead of `docker compose`** — includes correct compose files
- **Dev server is always running** — no need to start it
- Backend `.ts` changes auto-reload (nodemon). Frontend uses Vite HMR.
- Never run `npm run dev` / `npm start` — services run in Docker

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
| "verify in browser" | Open browser and verify yourself |
| "red/green TDD" | Run both unit tests and relevant E2E tests |
| "commit" | Pre-commit hook must pass |
| "push" | Pre-push hook must pass |
| "create pr" / "open pr" | Draft PR, gitmoji title, `risk:standard` label, `## Why` and `## What` sections, then open its URL in my browser |
| "save to vault" | Write a markdown file to `/Users/philip/vaults/work/dev` |

Committing and pushing don't need approval. Labels beyond `risk:standard` do.

### Failing Builds and Tests

Fix pre-existing lint or type errors first and commit that fix before starting
new work.

While master is green, a failing build, tool, or test comes from this branch.
Those are yours to fix and stay on, including the ones that look unrelated to
what you changed.

### Troubleshooting Dev Environment

Start with the container logs — they describe what actually happened, where
anything earlier is a guess.

1. `docker ps` to list running containers
2. Find the ones carrying this worktree's name (e.g. `worktree-name-registries-1`)
3. Read their logs, then restart or adjust those containers as needed

Only containers with the worktree name belong to this environment. A connection
failure means container state, not port configuration.

After opening a branch in a worktree, load the frontend URL and confirm the page
renders. **"An unknown error occurred. Please try again later or contact
support."** is a Docker-side problem, not an application bug — usually a service
needing a restart, an unrun migration, or missing dependencies.

### Datadog

Open a Datadog link and confirm it returns results before putting it in a
comment, PR, or report. These URLs are easy to construct plausibly and wrong; a
link showing nothing costs more than no link.

## Critical Rules

### Architecture

- 3-layer pattern: Handler → Application → Adapter
- Never import transport-generated types (GraphQL/gRPC) into application code
- Use cases depend on projection classes, never `PrismaClient` (except static reference tables)
- All domain mutations emit events; projections handle persistence
- Every handler must call `authorize()` before data access

### Code Style

- Comments explain _why_, never _what_ — see [code-style.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md) for when one is warranted
- Prefer early returns — narrow to the expected case, bail out on the rest
- No TypeScript enums — use string types or const maps
- Never use `as any` or `as unknown`
- One GraphQL operation per `.graphql` file
- Zod only at trust boundaries (API inputs, env vars, external responses)
- Never throw plain `Error` — use typed errors (`NotFoundError`, `ValidationError`, etc.)
- Handle caught error types explicitly, then rethrow what you didn't handle
- Spell words out — no invented acronyms or abbreviations
- No GitHub issue links (`#2858`) in source code

### Frontend

- shadcn/ui components before custom ones
- Translation keys for ALL UI text — never hardcode strings
- `DICTIONARY` at bottom of file, same file where used
- Don't destructure queries/forms (`const userQuery = useUserQuery()`)
- Minimize `useEffect` — prefer computed values
- Disable UI elements rather than removing them

### Testing

- Integration tests for backend, unit tests for edge cases
- MSW for GraphQL mocks, not custom Apollo client mocks
- Imperative descriptions: `it("reorders elements", ...)` not `it("should...")`
- Feature-flagged paths get tests in both the enabled and disabled state
- A bug fix starts with a failing test that reproduces it

## Reference

| Task | Documentation |
|------|---------------|
| Engineering principles | [principles.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/principles.md) |
| Post-change workflows | [workflows.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/workflows.md) |
| Architecture & patterns | [architecture.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md) |
| Backend development | [backend.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md) |
| Frontend development | [frontend.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/frontend.md) |
| Testing guidelines | [testing.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/testing.md) |
| Commands reference | [commands.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/commands.md) |
| Code style | [code-style.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md) |
| Git & PRs | [git.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/git.md) |
