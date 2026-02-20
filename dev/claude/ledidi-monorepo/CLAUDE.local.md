# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a monorepo for Ledidi, a medical registry and clinical studies platform. It uses npm workspaces with the following structure:

- `apps/main-frontend/` - React 19 + Vite frontend
- `services/` - Backend microservices (Node.js, Prisma)
  - `registries/` - Medical registries service (PostgreSQL, GraphQL + gRPC)
  - `codelist/` - Code list service (PostgreSQL, gRPC only)
  - `apollo-router/` - Apollo Federation GraphQL supergraph router
- `packages/` - Shared libraries (@ledidi-as npm scope)
  - `eslint/` - Shared ESLint configuration
  - `logger/` - Logging utilities
  - `authentication/` - Authentication helpers
  - `expression/` - Expression evaluation library

## Development Commands

**Requirements:** Node.js 24.11+ is required for backend services.

### Development Environment

The development environment is always running. Never run startup commands like:
- `docker compose up`
- `npm run dev`
- `npm start`

These services are already running and available.

### Restart vs Rebuild

- **`docker compose restart <service>`** — Restarts the container without rebuilding. Use this after code changes (`.ts`, `.graphql`) since source code is volume-mounted.
- **`docker compose up -d --build <service>`** — Rebuilds the Docker image and recreates the container. Use this after `package.json` or `Dockerfile` changes, since `node_modules` lives inside the image.

### Monorepo Workspace Commands

```bash
npm run lint:fix --workspaces --if-present
npm run build --workspaces --if-present
npm run test --workspaces --if-present
npm run generate --workspaces --if-present
```

### Post-Change Workflows

After making changes, follow the workflow that matches what you changed. Multiple workflows may apply (e.g., you edited both `.graphql` and `.ts` files).

#### Changed `.ts` files in a backend service (e.g., `services/registries/src/`)

No commands needed. The running Docker container mounts `src/` and uses nodemon to auto-reload on file changes.

> If for some reason the service is not picking up changes: `docker compose restart registries`

#### Changed `.graphql` schema files (e.g., `services/registries/api/*.graphql`)

This is the most involved workflow because GraphQL schema changes ripple through codegen, the supergraph, and the frontend.

1. **Regenerate types in the backend service that owns the schema:**
   ```bash
   cd services/registries && npm run generate
   ```

2. **The supergraph auto-recomposes.** A `router-autoupdate` container watches `api/*.graphql` files and automatically runs `rover supergraph compose`. The router has `--hot-reload` enabled so it picks up the new supergraph automatically. **You do NOT need to manually run `rover` or restart the router.**

   > If the auto-update is not working, you can manually recompose:
   > ```bash
   > rover supergraph compose --config services/apollo-router/supergraph.yaml 2>/dev/null > services/apollo-router/supergraph.graphql
   > ```

3. **Regenerate frontend GraphQL types** (if the frontend consumes the changed types):
   ```bash
   cd apps/main-frontend && npm run generate
   ```

4. **Restart the backend service** to pick up any new resolvers or type changes:
   ```bash
   docker compose restart registries
   ```

**Summary for GraphQL changes:**
```bash
cd services/registries && npm run generate
cd apps/main-frontend && npm run generate
docker compose restart registries
```

#### Changed `.proto` files (gRPC schema)

1. Regenerate proto types in the affected service:
   ```bash
   cd services/registries && npm run generate-proto
   ```
2. Regenerate proto types in any consuming service.
3. Restart affected services:
   ```bash
   docker compose restart registries
   ```

#### Changed `prisma/schema.prisma` in a backend service

1. Create a migration:
   ```bash
   cd services/registries && npm run migrate-create
   ```
   This creates a migration file in `prisma/migrations/`. Review the generated SQL.

2. Apply the migration:
   ```bash
   cd services/registries && npm run migrate
   ```

3. Regenerate Prisma client:
   ```bash
   cd services/registries && npm run generate
   ```

4. Restart the service:
   ```bash
   docker compose restart registries
   ```

**Important:** Always use the package.json scripts for migrations. Never run `npx prisma migrate dev` or `npx prisma generate` directly.

#### Changed `package.json` (added/removed/updated dependencies)

1. Install from the monorepo root:
   ```bash
   npm install
   ```

2. **Rebuild** the Docker container (not just restart, since `node_modules` is baked into the image):
   ```bash
   docker compose up -d --build <service>
   ```

   For example: `docker compose up -d --build registries`

   > A plain `docker compose restart` will NOT pick up new dependencies because the container's `node_modules` comes from the image build, not a host volume mount.

#### Changed frontend files (`apps/main-frontend/src/`)

No commands needed. Vite HMR handles live reloading inside the Docker container (the `src/` directory is volume-mounted).

#### Changed frontend `.graphql` operation files (queries/mutations in `apps/main-frontend/src/`)

The frontend dev server runs `generate-watch` which watches for `.graphql` file changes and auto-regenerates types. No manual action needed.

> If types seem stale: `cd apps/main-frontend && npm run generate`

### What `npm run generate` produces

| Workspace | Command | Generates |
|-----------|---------|-----------|
| `services/registries` | `npm run generate` | GraphQL resolver types, Prisma client, gRPC/proto TS types |
| `services/codelist` | `npm run generate` | Prisma client, gRPC/proto TS types (no GraphQL) |
| `apps/main-frontend` | `npm run generate` | Typed GraphQL hooks and types from all service schemas |

**When to run it:**
- After changing any `.graphql` schema file → run in the owning service AND in `apps/main-frontend`
- After changing `prisma/schema.prisma` → run in the owning service
- After changing `.proto` files → run in the owning service and any consuming services
- After pulling new code from git → run in all workspaces: `npm run generate --workspaces --if-present`

### Frontend Commands

```bash
npm run build           # Production build
npm run generate        # Generate GraphQL types
npm run lint:fix        # Fix linting issues
npm run test            # Unit tests (Vitest)
npm run test:e2e        # E2E tests (Playwright)
```

Verification: `cd apps/main-frontend && npm run lint:fix && npm run build`

### Backend Service Commands

Each service follows the same pattern:

```bash
npm run build           # Full build (generate + tsc)
npm run build-ts        # TypeScript-only build (faster, no codegen)
npm run generate        # Generate GraphQL, Prisma, gRPC types
npm run test            # Run integration tests (starts test DB)
npm run test:watch      # Watch mode testing
npm run lint:fix        # Fix linting issues
npm run migrate         # Deploy database migrations
```

Backend tests require `--runInBand` flag (handled automatically by npm scripts).

```bash
# Run a specific test by pattern
npm run test -- --testPathPattern="get-registries"
```

Verification: `cd services/registries && npm run lint:fix && npm run build-ts`

Docker compose service names: `main-frontend`, `registries`, `codelist`, `router`

> `router-autoupdate` also exists but rarely needs manual interaction.

### Common Mistakes

- **Running `docker compose up` or `npm run dev`** — The dev environment is always running. These commands are not needed and may cause port conflicts.
- **Running `npx prisma migrate dev` directly** — Always use the service's package.json scripts (`npm run migrate`, `npm run migrate-create`).
- **Restarting instead of rebuilding after dependency changes** — `docker compose restart` does not pick up new `node_modules`. Use `docker compose up -d --build <service>`.
- **Forgetting to regenerate frontend types after backend schema changes** — If you change a `.graphql` file in a service, also run `cd apps/main-frontend && npm run generate`.
- **Manually running `rover` to recompose the supergraph** — The `router-autoupdate` container handles this automatically. Only run `rover` manually if auto-update appears broken.
- **Using `cd` in chained commands** — In a monorepo, prefer running commands from the repo root with explicit paths, or use separate shell invocations. `cd services/registries && npm run generate` works, but note that `cd` persists in the shell session.

## Architecture

### Backend Layered Architecture

Services follow a 3-layer pattern:

- **Handler layer** (`src/handlers/`) - GraphQL resolvers, gRPC handlers, HTTP endpoints
- **Application layer** (`src/application/`) - Business logic and authorization
- **Adapter layer** (`src/adapters/`) - External integrations and persistence

### Handler Architecture

Each service orchestrates three handler types in `src/handlers/index.ts`:

- **GraphQL Handler** - Fastify + Apollo Server for frontend queries/mutations
- **gRPC Handler** - Service-to-service communication
- **Cron Handler** - Scheduled background tasks

All handlers receive `logger`, `environment`, `application`, and `ports` as dependencies.

### Ports & Dependency Injection

Each service defines a `Ports` type in `src/ports/index.ts` containing all external dependencies:

```typescript
type Ports = {
  authentication: AuthenticationProvider;
  authorizationRepository: AuthorizationRepository;
  registryProjection: RegistryProjection;
  eventStore: EventStore;
  // ... other dependencies
};
```

This enables complete dependency injection and test mocking. Use cases and handlers receive ports as constructor arguments, never importing singletons directly.

### Projection Pattern

Services use projection classes for read models that transform event store data into queryable views:

- Located in `src/adapters/projections/`
- Examples: `RegistryProjection`, `FormProjection`, `PatientProjection`
- Injected as dependencies into use cases
- Enable efficient queries without re-processing events

### GraphQL Federation

Apollo Router federates subgraph schemas from each service. Each service has its schema in `api/*.graphql`.

### Service Communication

- Service-to-service: gRPC with ts-proto
- Frontend-to-backend: GraphQL via Apollo Router
- Authorization: SpiceDB for ACL, OAuth2 service tokens

### Frontend Technology Stack

- **Styling**: Tailwind CSS v4 with `clsx` + `tailwind-merge` for className composition
- **UI Components**: shadcn/ui pattern in `src/components/ui/`
- **Forms**: React Hook Form + Zod 4 for validation
- **State**: Apollo Client for server state, React Context for local state
- **Routing**: React Router v7

### Frontend Error Handling

Use error helpers from `src/lib/errors.ts` to check GraphQL error codes:

```typescript
import { isNotFoundError, isFailedPreconditionError } from "~/lib/errors";

if (isNotFoundError(error)) {
  // Handle 404 case
}
if (isFailedPreconditionError(error)) {
  // Handle precondition failure
}
```

These helpers check `error.graphQLErrors` for matching error codes from the backend.

### Backend Technology Stack

- **GraphQL Services** (admin, studies, registries, auth): Fastify + Apollo Server
- **Codelist Service**: Express + gRPC only (no GraphQL)
- **Use Cases**: Follow `buildXxxUseCase` builder pattern
- **Test Utilities**: Use `test_*` helpers from `test-utils.ts` (e.g., `test_createStudy`, `mockContext`)

### Backend Error Handling

Each service defines typed errors in `src/application/errors.ts`:

```typescript
// Error types: NotFoundError, NotAuthorizedError, ValidationError,
// AlreadyExistsError, FailedPreconditionError, RetryableError, etc.

throw new NotFoundError({
  message: "Registry not found",
  subcode: ErrorSubcode.RegistryNotFound,
});
```

All errors extend `ApplicationError` and use `ErrorSubcode` enums for granular error handling. Frontend can check these via GraphQL error codes.

### Backend Test Setup

Use `buildTestApplication()` from `src/test/test-application.ts` with optional port overrides:

```typescript
const { application } = buildTestApplication({
  overridePorts: {
    emailService: mockEmailService,  // Override specific dependencies
  },
});

const context = mockContext({
  userId: "test-user-id",
  allowedScopes: ["registry:read", "registry:write"],
});

await application.createRegistry.run({ input, context });
```

## Code Style Guidelines

### General

- Prefer descriptive variable names over short/vague ones like `data`, `info`, `item`
- Use generous newlines between code blocks
- Comments explain _why_, not _how_
- No TypeScript enums - use string types or const maps
- Use Zod for parsing unknown types
- Use npm (not pnpm)

### File Naming

- General files: kebab-case (`user-details.tsx`, `create-study.ts`)
- React hooks: camelCase starting with `use` (`useFormId.ts`, `useStudyId.ts`)
- GraphQL operations: camelCase (`getForms.graphql`, `createStudy.graphql`)

### Backend (services/**/*.ts)

- Use lowercase first letter for Prisma relations
- Integration tests for backend changes
- Unit tests for edge cases that integration tests can't cover

### Frontend (apps/main-frontend/)

- Minimize useEffect - prefer computed values
- Don't destructure queries/forms:
  ```typescript
  // Good
  const userQuery = useUserQuery();
  // Avoid
  const { data, isLoading } = useUserQuery();
  ```
- Use descriptive function names for what they do, not when invoked:
  ```typescript
  // Good
  const submitLoginCredentials = () => { ... }
  // Avoid
  const handleButtonClicked = () => { ... }
  ```
- Use Luxon `DateTime.toLocaleString` for date formatting
- Use `useXXXId` hooks for type-safe route params (e.g., `useRegistryId`, `useFormId`)
- Use `ROUTE_MAP` for type-safe navigation paths (see `src/features/route-map/`)
- Deletions require a confirmation dialog

### Dictionaries

Use function parameters for dynamic values:
```typescript
// Good
fullName: (firstName: string, lastName: string) => `${firstName} ${lastName}`
// Avoid
fullName: `{firstName} {lastName}` // with .replace()
```

For static translations, use language-keyed objects. Define the `DICTIONARY` in the same file where translations are used:
```typescript
const DICTIONARY = {
  en: { title: "Users", status: "Status" },
  no: { title: "Brukere", status: "Status" },
} as const;
```

### GraphQL

- One operation per `.graphql` file

### Testing

**Test file locations:**
- Frontend unit tests: `src/**/*.test.ts(x)` (Vitest)
- Frontend E2E tests: `src/app/**/*.spec.tsx` (Playwright)
- Backend integration tests: `src/**/*.integration.test.ts` (Jest)

**Guidelines:**
- Extract shared setup into `beforeAll`, assertions in `it` blocks
- Prefer `toEqual` over `toMatchObject`
- Use imperative test descriptions:
  ```typescript
  // Good
  it("reorders the elements", ...)
  // Avoid
  it("should reorder the elements", ...)
  ```
