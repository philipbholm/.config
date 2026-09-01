# CLAUDE.md

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

The reference docs linked at the bottom of this file live outside the worktree,
so their ports are never filled in — they appear as double-braced names like the
Postgres one. Read the real value from the table above; never type the braced
form into a command.

## Workflow

### Worktrees

Worktrees live at `<repo>/.worktrees/<name>` — nowhere else. The path is shared
by every agent harness.

- **New branch** → `wt-up <name> <branch> [start-point]`.
- **Existing branch** → `wt-up <name> <branch>`.
- Continue the task from the path printed by `wt-up`, then run `setup-stack`.
- Always choose an explicit name. The directory name becomes the Docker stack
  ID, so generated names produce unpredictable compose project names and
  orphaned slot files.
- `setup-stack` installs dependencies and generates types. It starts no
  containers.

### Starting containers

The Docker stack is opt-in, and different work needs different amounts of it.
Start the row that matches the task:

| Task | Command |
|------|---------|
| tsc, biome, frontend unit tests | nothing — `setup-stack` covers it |
| Backend suite (`services/registries`) | `dev up postgres -d` |
| Playwright E2E, browser verification | `dev up` |

Postgres alone carries the backend suite: the vitest global setup
(`src/test-setup.ts`) runs `generate` and `migrate-reset --force` against
`POSTGRES_URL`, building `registries-test` itself. Starting postgres alone also
skips the admin-mock container that `registries` requires.

`dev up` fills in the port table above — there is no separate `sync-context` to
run. It also writes `services/registries/.env.test.local` pointing at the test
database, but only when `registries` is one of the services it started. So after
a full `dev up` the backend suite runs on a bare `npm run test`; after
`dev up postgres` pass `POSTGRES_URL` on the command line as
[commands.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/commands.md)
shows. The port comes from the table, never from an edited config file.

Run each suite directly — no wrapper decides for you. The container table above
says which ones the current stack supports: frontend unit tests need nothing, the
registries suite needs postgres, e2e needs everything. Vitest's
`--changed origin/master` narrows a run to the tests your change reaches through
the import graph, and both `services/registries` and `apps/registries-frontend`
accept it; `services/codelist` is on Jest and has no equivalent.

Nothing flags a suite you never started, so a green frontend run is not a green
branch. Say which suites ran and which the current stack couldn't support.

### Tearing down

**Not until the PR is merged.** The stack stays up for the whole life of the
branch. A green suite is not a reason to stop it, and neither is the end of a
session. Never run `dev down`, `dev nuke`, or `wt-down` on your own initiative.

`dev restart <service>` and `dev up --build <service>` are not teardown — use
them freely while working.

When you finish with containers still running, name the stack and its ports so
nothing is left running silently.

After the merge, teardown is `wt-down` from inside the worktree. Not
`ExitWorktree action:remove`, which deletes the branch and leaves the Docker
stack orphaned.

### Environment

- **Use `dev` instead of `docker compose`** — includes correct compose files
- With the stack up, backend `.ts` changes auto-reload (nodemon) and the
  frontend uses Vite HMR
- Generated code never reloads. `.graphql`, `.proto` and `prisma/schema.prisma`
  changes need an explicit codegen pass, and for schema changes the order matters
  — see [workflows.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/workflows.md)
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
| "verify in browser" | Start the full stack if it isn't up, then open the browser and verify yourself |
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

- Comments are a last resort — a name that says it makes the comment unnecessary
- Comment only what the code cannot express (hidden constraint, workaround, surprising invariant), never _what_ the code does. A comment that stays must stand on its own — spell the thing out instead of pointing at it — see [code-style.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md)
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
