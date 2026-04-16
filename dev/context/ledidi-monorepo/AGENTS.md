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

**Never touch `apps/main-frontend/`.** Always use `apps/registries-frontend/`.

## Ports (Worktree-Specific)

This is one of many parallel worktrees, each with its own isolated Docker stack and unique ports.

| Service | URL |
|---------|-----|
| Frontend | http://localhost:{{FRONTEND_PORT}}/en/registries |
| Registries (GraphQL) | http://localhost:{{REGISTRIES_PORT}}/graphql |
| Registries (gRPC) | localhost:{{REGISTRIES_GRPC_PORT}} |
| Codelist (gRPC) | localhost:{{CODELIST_GRPC_PORT}} |
| PostgreSQL | localhost:{{POSTGRES_PORT}} |

**Critical:**
- These ports are assigned to this worktree only. Never try alternative ports (e.g., 5432, 3000, 4000).
- Never modify hardcoded URLs, environment files, or config files to change ports for running tests or fixing connection issues.
- If a port doesn't work, the issue is the Docker stack, not the port number.

## Workflow

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
| "save to vault" | Write a markdown file to `/Users/philip/vaults/main/dev` |

### Error Handling

If there are pre-existing lint or type errors, fix them first and commit the fix before starting new work.

### Troubleshooting Dev Environment

If the dev environment seems broken (connection refused, services not responding):

1. Run `docker ps` to list running containers
2. Look for containers with the current worktree name (e.g., `worktree-name-registries-1`)
3. Only containers containing the worktree name belong to this environment — you can restart/modify these
4. Do NOT try different ports or modify configs. The assigned ports are correct; the issue is the container state.

## Critical Rules

### Architecture

- 3-layer pattern: Handler → Application → Adapter
- Never import transport-generated types (GraphQL/gRPC) into application code
- Use cases depend on projection classes, never `PrismaClient` (except static reference tables)
- All domain mutations emit events; projections handle persistence
- Every handler must call `authorize()` before data access

### Code Style

- No TypeScript enums — use string types or const maps
- Never use `as any` or `as unknown`
- One GraphQL operation per `.graphql` file
- Zod only at trust boundaries (API inputs, env vars, external responses)
- Never throw plain `Error` — use typed errors (`NotFoundError`, `ValidationError`, etc.)

### Frontend

- shadcn/ui components before custom ones
- Translation keys for ALL UI text — never hardcode strings
- `DICTIONARY` at bottom of file, same file where used
- Don't destructure queries/forms (`const userQuery = useUserQuery()`)
- Minimize `useEffect` — prefer computed values

### Testing

- Integration tests for backend, unit tests for edge cases
- MSW for GraphQL mocks, not custom Apollo client mocks
- Imperative descriptions: `it("reorders elements", ...)` not `it("should...")`

## Reference

| Task | Documentation |
|------|---------------|
| Post-change workflows | [workflows.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/workflows.md) |
| Architecture & patterns | [architecture.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md) |
| Backend development | [backend.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md) |
| Frontend development | [frontend.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/frontend.md) |
| Testing guidelines | [testing.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/testing.md) |
| Commands reference | [commands.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/commands.md) |
| Code style | [code-style.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md) |
| Git & PRs | [git.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/git.md) |
