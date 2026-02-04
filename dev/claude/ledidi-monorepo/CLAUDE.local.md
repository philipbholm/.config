# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a monorepo for Ledidi, a medical registry and clinical studies platform. It uses npm workspaces with the following structure:

- `apps/main-frontend/` - React 19 + Vite frontend
- `services/` - Backend microservices (Node.js, Prisma)
  - `admin/` - Admin service (MariaDB, GraphQL + gRPC)
  - `studies/` - Studies/Projects service (PostgreSQL, GraphQL + gRPC)
  - `registries/` - Medical registries service (PostgreSQL, GraphQL + gRPC)
  - `codelist/` - Code list service (PostgreSQL, gRPC only)
  - `auth/` - Authorization service (SpiceDB, GraphQL + gRPC)
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

These services are already running and available. Just proceed directly with your tasks.

App runs at http://localhost:3001/en/registries

### Monorepo Workspace Commands

Always use workspace flags for monorepo-wide operations:

```bash
npm run lint:fix --workspaces --if-present
npm run build --workspaces --if-present
npm run test --workspaces --if-present
npm run generate --workspaces --if-present
```

### Rebuilding Services

Before verifying changes in the browser, rebuild the affected services using `rebuild`:

```bash
rebuild <service>                    # Auto-detects what changed, only runs needed steps
rebuild frontend registries          # Multiple services (built in parallel)
rebuild registries --full            # Force all steps (deps + build + migrate + supergraph)
rebuild registries --deps --migrate  # Force specific steps
```

Services: `frontend`, `registries`, `studies`, `admin`, `codelist`

When multiple services are specified, npm installs and Docker builds run in parallel for faster rebuilds. Migrations still run sequentially since they depend on the database.

The script auto-detects changes via `git diff` and only runs the steps that are needed:
- `package.json` / `package-lock.json` changed → runs `npm install` before docker rebuild
- `prisma/` files changed → runs migrations after docker rebuild
- `.graphql` files changed → regenerates the supergraph after docker rebuild
- Source code only → just runs `docker compose up -d --build`

Use `--full` / `-f` to force all steps, `--deps` / `-d` to force npm install, or `--migrate` / `-m` to force migrations.

### Pre-commit Checks

Run before completing work to verify that changed files pass formatting, linting, and tests. Automatically scopes to files changed vs the base branch (default: `master`).

```bash
check                # Check changed files against master
check main           # Check changed files against a different base branch
```

Runs `prettier --write`, `eslint --fix`, and tests on affected files only. Frontend uses Vitest, backend services use Jest.

### Database Shell

Use when you need to inspect or debug data directly in a service's database.

```bash
db <service>         # Open a database shell
```

Services: `admin` (MySQL), `studies`, `codelist`, `registries` (PostgreSQL)

### Container Shell

Use when you need to run commands inside a running container (e.g., inspect files, run one-off scripts).

```bash
shell <service>      # Open a shell in the service's container
```

Services: `frontend`, `registries`, `studies`, `admin`, `codelist`, `auth`

### Frontend (apps/main-frontend/)

```bash
npm run dev             # Development server (port 3001)
npm run build           # Production build
npm run generate        # Generate GraphQL types
npm run lint:fix        # Fix linting issues
npm run test            # Unit tests (Vitest)
npm run test -- inline-text-input  # Run single test file
npm run test:e2e        # E2E tests (Playwright)
npm run test:e2e -- create-study   # Run single E2E spec
npm run storybook       # Component library (port 6006)
```

### Backend Services (services/*)

Each service follows the same pattern:

```bash
npm run dev             # Development mode with watch
npm run build           # Full build (generate + tsc)
npm run generate        # Generate GraphQL, Prisma, gRPC types
npm run test            # Run integration tests (starts test DB)
npm run test -- --testPathPattern="create-analysis"  # Run single test
npm run test:watch      # Watch mode testing
npm run lint:fix        # Fix linting issues
npm run migrate         # Deploy database migrations
```

Backend tests require `--runInBand` flag (handled automatically by npm scripts).

**Database Migrations:** Use package.json scripts, NOT raw prisma commands. Check each service's package.json for migration scripts. Do NOT use `npx prisma migrate dev` or `npx prisma generate` directly.

Individual services may have their own `CLAUDE.md` with service-specific guidance (e.g., `services/registries/CLAUDE.md`).

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
- Always create/update integration tests for backend changes
- Use unit tests only when integration tests can't cover edge cases

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
- Deletions always require a confirmation dialog

### Dictionaries

Use function parameters for dynamic values:
```typescript
// Good
fullName: (firstName: string, lastName: string) => `${firstName} ${lastName}`
// Avoid
fullName: `{firstName} {lastName}` // with .replace()
```

For static translations, use language-keyed objects. Always define the `DICTIONARY` in the same file where the translations are used:
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
- At least one E2E test per main feature flow (create, update, delete)
- Extract shared setup into `beforeAll`, assertions in `it` blocks
- Prefer `toEqual` over `toMatchObject`
- Use imperative test descriptions:
  ```typescript
  // Good
  it("reorders the elements", ...)
  // Avoid
  it("should reorder the elements", ...)
  ```
- Always run tests and ensure code compiles before completing work
