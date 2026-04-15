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

## Ports

| Service | URL |
|---------|-----|
| Frontend | http://localhost:{{FRONTEND_PORT}}/en/registries |
| Registries (GraphQL) | http://localhost:{{REGISTRIES_PORT}}/graphql |
| Registries (gRPC) | localhost:{{REGISTRIES_GRPC_PORT}} |
| Codelist (gRPC) | localhost:{{CODELIST_GRPC_PORT}} |
| PostgreSQL | localhost:{{POSTGRES_PORT}} |

**Always use `{{POSTGRES_PORT}}` for database connections, never `5432`.**

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

### Error Handling

If there are pre-existing lint or type errors, fix them first and commit the fix before starting new work.

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
