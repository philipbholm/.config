# CLAUDE.md

This file provides guidance to agents when working with code in this repository.

## Project Overview

This is a monorepo for Ledidi, a medical registry platform. It uses npm workspaces with the following structure:

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

### Development Environment

The development environment is always running. **Always use `dev` instead of `docker compose`** — it automatically includes the correct compose files for your environment. Running `docker compose` directly will use wrong ports and break the stack.

### Common Commands

- `dev restart <service>` — Restart a service if it's not picking up changes automatically
- `dev up --build <service> -d` — Rebuild after package.json/Dockerfile changes (node_modules is in the image)
- `dev exec <service> sh` — Shell into a running container
- `dev logs -f <service>` — Tail service logs
- `dev ps` — List running containers

Never run:
- `docker compose up` / `docker compose restart` — missing override files, will break ports
- `npm run dev` / `npm start` — services run in Docker


### Post-Change Workflows

After making changes, follow the workflow that matches what you changed. Multiple workflows may apply (e.g., you edited both `.graphql` and `.ts` files).

#### Changed `.ts` files in a backend service (e.g., `services/registries/src/`)

No commands needed. The running Docker container mounts `src/` and uses nodemon to auto-reload on file changes.

> If for some reason the service is not picking up changes: `dev restart registries`

#### Changed `.graphql` schema files (e.g., `services/registries/api/*.graphql`)

This is the most involved workflow because GraphQL schema changes ripple through codegen, the supergraph, and the frontend.

1. **Regenerate types in the backend service that owns the schema:**
```bash
cd services/registries && npm run generate
```

2. **Recompose the supergraph** — a `router-autoupdate` container should do this automatically, but it doesn't always work reliably. Always run this manually after GraphQL schema changes:
```bash
rover supergraph compose --config services/apollo-router/supergraph.yaml 2>/dev/null > services/apollo-router/supergraph.graphql
```

3. **Regenerate frontend GraphQL types** (if the frontend consumes the changed types):
```bash
cd apps/main-frontend && npm run generate
```

4. **Restart the backend service** to pick up any new resolvers or type changes:
```bash
dev restart registries
```

5. **Restart the router** to pick up the recomposed supergraph:
```bash
dev restart router
```

**Summary for GraphQL changes:**
```bash
cd services/registries && npm run generate
rover supergraph compose --config services/apollo-router/supergraph.yaml 2>/dev/null > services/apollo-router/supergraph.graphql
cd apps/main-frontend && npm run generate
dev restart registries
dev restart router
```

#### Changed `.proto` files (gRPC schema)

1. Regenerate proto types in the affected service:
```bash
cd services/registries && npm run generate-proto
```
2. Regenerate proto types in any consuming service.
3. Restart affected services:
```bash
dev restart registries
```

#### Changed `prisma/schema.prisma` in a backend service

Prisma commands connect to PostgreSQL from the host, so you must override `POSTGRES_URL` with the correct port from the ports table at the bottom of this file. Replace `<PORT>` below with that port.

1. Create a migration:
```bash
cd services/registries && POSTGRES_URL="postgresql://postgres:postgres@localhost:<PORT>/registries" npm run migrate-create
```

This creates a migration file in `prisma/migrations/`. Review the generated SQL.

2. Apply the migration:
```bash
cd services/registries && POSTGRES_URL="postgresql://postgres:postgres@localhost:<PORT>/registries" npm run migrate
```

3. Regenerate Prisma client:
```bash
cd services/registries && POSTGRES_URL="postgresql://postgres:postgres@localhost:<PORT>/registries" npm run generate
```

4. Restart the service:
```bash
dev restart registries
```

**Important:** Always use the package.json scripts for migrations. Never run `npx prisma migrate dev` or `npx prisma generate` directly.

#### Changed `package.json` (added/removed/updated dependencies)

1. Install dependencies in the workspace that changed:
```bash
cd services/registries && npm install
```

2. **Rebuild** the Docker container (not just restart, since `node_modules` is baked into the image):
```bash
dev up --build <service> -d
```

For example: `dev up --build registries -d`

> A plain `dev restart` will NOT pick up new dependencies because the container's `node_modules` comes from the image build, not a host volume mount.

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


### Frontend Commands

```bash
npm run build           # Production build
npm run generate        # Generate GraphQL types
npm run lint:fix        # Fix linting issues
npm run test            # Unit tests (Vitest)
```

E2E tests (Playwright) require environment variables with the correct ports from the ports table at the bottom of this file. Replace `<FRONTEND_PORT>` and `<API_PORT>` below with those ports.

```bash
cd apps/main-frontend && FRONTEND_BASE_URL="http://localhost:<FRONTEND_PORT>" E2E_API_URL="http://localhost:<API_PORT>" npx playwright test
```

Verification: `cd apps/main-frontend && npm run lint:fix && npm run build && FRONTEND_BASE_URL="http://localhost:<FRONTEND_PORT>" E2E_API_URL="http://localhost:<API_PORT>" npx playwright test`

### Backend Service Commands

Each service follows the same pattern:

```bash
npm run lint:fix        # Fix linting issues
npm run build           # Full build (generate + tsc)
npm run build-ts        # TypeScript-only build (faster, no codegen)
npm run generate        # Generate GraphQL, Prisma, gRPC types
```

`test` and `migrate` require `POSTGRES_URL` with the correct port from the ports table at the bottom of this file. Replace `<PORT>` below with that port.

```bash
# Run integration tests
POSTGRES_URL="postgresql://postgres:postgres@localhost:<PORT>/registries-test" npm run test

# Run a specific test by pattern
POSTGRES_URL="postgresql://postgres:postgres@localhost:<PORT>/registries-test" npm run test -- --testPathPattern="get-registries"

# Deploy database migrations
POSTGRES_URL="postgresql://postgres:postgres@localhost:<PORT>/registries" npm run migrate
```

Verification: `cd services/registries && npm run lint:fix && npm run build-ts && POSTGRES_URL="postgresql://postgres:postgres@localhost:<PORT>/registries-test" npm run test`

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
- Authentication: JWT tokens (JWKS-verified), separate JWT for service-to-service
- Authorization: Custom RBAC stored in PostgreSQL (subject-object-relation permission tuples)

## Backend

- **Registries Service**: Fastify + Apollo Server
- **Codelist Service**: Express + gRPC only (no GraphQL)
- **Use Cases**: Follow `buildXxxUseCase` builder pattern

### Error Handling

Each service defines typed errors in `src/application/errors.ts`:

```typescript
throw new NotFoundError({
  message: "Registry not found",
  subcode: ErrorSubcode.RegistryNotFound,
});
```

All errors extend `ApplicationError` and use `ErrorSubcode` enums for granular error handling. **Never throw plain `Error`.** Always use the appropriate typed error class (e.g., `NotFoundError`, `ValidationError`, `NotAuthorizedError`).

## Frontend

- **Styling**: Tailwind CSS v4 with the `cn` function from shadcn for className composition
- **UI Components**: shadcn/ui pattern in `src/components/ui/`
- **Forms**: React Hook Form + Zod 4 for validation
- **State**: Apollo Client for server state, React Context for local state
- **Routing**: React Router v7

### Error Handling

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

## Testing

### Test File Locations

- Frontend unit tests: `src/**/*.test.ts(x)` (Vitest)
- Frontend E2E tests: `src/app/**/*.spec.tsx` (Playwright)
- Backend integration tests: `src/**/*.integration.test.ts` (Jest)

### Guidelines

- Extract shared setup into `beforeAll`, assertions in `it` blocks
- Prefer `toEqual` over `toMatchObject`
- Use imperative test descriptions:
```typescript
// Good
it("reorders the elements", ...)
// Avoid
it("should reorder the elements", ...)
```
- Integration tests for backend changes
- Unit tests for edge cases that integration tests can't cover

### Backend Test Setup

Use `buildTestApplication()` from `services/registries/src/test/test-application.ts` and `registryTestBuilder` from `services/registries/src/test/test-setup-builder.ts`:

```typescript
const { application } = buildTestApplication({
  overridePorts: {
    emailService: mockEmailService,
  },
});

const context = mockContext({
  userId: "test-user-id",
  allowedScopes: ["registry:read", "registry:write"],
});

// Fluent builder — auto-creates dependencies (e.g., withPatient creates a registry first)
const result = await registryTestBuilder(application, context)
  .withRegistry()
  .withPatient()
  .withEpisode()
  .withEvent()
  .build();
```

### Frontend E2E Test Setup

Use `e2eRegistryTestBuilder` from `apps/main-frontend/test-util/e2e-registry-test-setup-builder.ts` — same fluent pattern as the backend builder:

```typescript
const result = await e2eRegistryTestBuilder(client)
  .withEvent({ repeatable: true })
  .withTextFormElement({ label: "Test Text Field", variableName: "test_text_field" })
  .withFormToEvent()
  .withPatientEventEntry()
  .withFormDataEntry()
  .build();
```

## Code Style

### General

- Prefer descriptive variable names over short/vague ones like `data`, `info`, `item`
- Use generous newlines between code blocks
- Avoid unnecessary comments. Only use comments to explain _why_ some code exists, not _what_ it does. If code needs a comment to explain what it does, the code should be rewritten to be self-explanatory.
- No TypeScript enums - use string types or const maps
- NEVER use the `any` type or cast types (e.g., `as SomeType`, `as unknown`). Use proper type narrowing, generics, or Zod parsing instead.
- Use Zod for parsing unknown types
- One GraphQL operation per `.graphql` file
- ALWAYS declare types that depend on other types _after_ the type they depend on:
```typescript
// Good — base type declared first
type Column = {
  id: string;
  label: string;
};

type ColumnConfig = {
  columns: Column[];
  defaultSort: Column["id"];
};

// Bad — ColumnConfig references Column before it's declared
type ColumnConfig = {
  columns: Column[];
  defaultSort: Column["id"];
};

type Column = {
  id: string;
  label: string;
};
```

### File Naming

- General files: kebab-case (`user-details.tsx`, `create-study.ts`)
- React hooks: camelCase starting with `use` (`useFormId.ts`, `useStudyId.ts`)
- GraphQL operations: camelCase (`getForms.graphql`, `createStudy.graphql`)

### File Structure Ordering

Place the following at the **bottom** of the file, in this order:

1. Zod schemas and inferred types
2. `DICTIONARY`

```typescript
// --- rest of the file's logic above ---

const formSchema = z.object({
  title: z.string(),
  numberOfTestPatients: z.number().int().min(0),
});
type FormData = z.infer<typeof formSchema>;

const DICTIONARY = {
  en: { title: "Settings", save: "Save" },
  no: { title: "Innstillinger", save: "Lagre" },
} as const;
```

### Backend Style (services/**/*.ts)

- Use lowercase first letter for Prisma relations

### Frontend Style (apps/main-frontend/)

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

- ALWAYS define `DICTIONARY` in the same file where translations are used — NEVER create separate `dictionary.ts` files
- Place `DICTIONARY` at the bottom of the file (see [File Structure Ordering](#file-structure-ordering))
- Use function parameters for dynamic values:
```typescript
// Good
fullName: (firstName: string, lastName: string) => `${firstName} ${lastName}`
// Avoid
fullName: `{firstName} {lastName}` // with .replace()
```
- Use language-keyed objects for static translations:
```typescript
const DICTIONARY = {
  en: { title: "Users", status: "Status" },
  no: { title: "Brukere", status: "Status" },
} as const;
```
