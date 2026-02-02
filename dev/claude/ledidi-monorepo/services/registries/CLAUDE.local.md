# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Service Overview

The registries service is a backend microservice for managing medical registries, patient data, forms, and clinical data collection. It exposes both GraphQL (via Apollo Server + Fastify) and gRPC APIs.

## Development Commands

```bash
npm run build              # Generate types + compile TypeScript
npm run generate           # Generate GraphQL, Prisma, and gRPC types
npm run dev                # Development mode with hot reload
npm run test               # Run all tests (uses --runInBand)
npm run test:watch         # Watch mode with test DB lifecycle
npm run lint:fix           # Fix ESLint + Prettier issues
npm run migrate            # Deploy Prisma migrations
npm run migrate-create     # Create new migration
```

### Running a Single Test

```bash
npm run test -- --testPathPattern="create-analysis"
```

## Architecture

### 3-Layer Structure

```
src/
├── handlers/          # Entry points (GraphQL resolvers, gRPC handlers, cron jobs)
│   ├── graphql/       # GraphQL resolvers that call application layer
│   └── grpc/          # gRPC service handlers
├── application/       # Business logic organized by domain
│   ├── {domain}/      # Each domain has use cases, projections, models
│   └── errors.ts      # Typed application errors with subcodes
├── adapters/          # External service integrations
│   ├── event-store/   # Event sourcing persistence
│   └── *.ts           # Repository implementations
└── ports/             # Dependency injection interfaces
```

### Use Case Pattern

Use cases follow a builder pattern with explicit authorization:

```typescript
export function buildCreateAnalysisUseCase(dependencies: {
    eventStore: EventStore;
    authorizationService: AuthorizationService;
}): CreateAnalysisUseCase {
    return {
        authorize: async ({ context, input }) => {
            return dependencies.authorizationService.hasPermission({...});
        },
        run: async ({ input, context }) => {
            // Business logic here
        },
    };
}
```

Use `buildAuthorizedUseCases()` to wrap use cases with authorization checks.

### Event Sourcing

The service uses event sourcing with projections:
- `EventStore` - stores domain events
- `*Projection` classes - materialize events into read models
- Events are scoped to registries and have `entityType` + `entityId`

### Ports Pattern

Dependencies are injected via the `Ports` type defined in `src/ports/index.ts`. This enables test stubbing.

## Testing

### Integration Tests

- Use `buildTestApplication()` from `src/test/test-application.ts`
- Use `mockContext({ userId: "..." })` for test contexts
- Tests use a shared Postgres container (via `docker-compose.test.yml`)

```typescript
describe("CreateAnalysis", () => {
    let testApplicationSetup: TestApplicationSetup;

    beforeAll(async () => {
        testApplicationSetup = await buildTestApplication();
        // Setup test data using testApplicationSetup.application.*
    });

    it("creates the analysis", async () => {
        const result = await testApplicationSetup.application.createAnalysis({
            context: mockContext({ userId: authorizedUserId }),
            input: {...},
        });
        expect(result.analysis).toEqual({...});
    });
});
```

## Key Files

- `api/registries.graphql` - GraphQL schema (federated subgraph)
- `api/registries-import.proto` - gRPC service definition
- `prisma/schema.prisma` - Database schema
- `src/application/index.ts` - Application use case composition
- `src/application/errors.ts` - Typed errors with subcodes

## Domain Concepts

- **Registry** - A medical registry containing forms, patients, and data
- **Patient** - Registry participant with codelist record (encrypted PII)
- **Event** - A repeatable data collection point (e.g., "Baseline", "Follow-up")
- **Episode** - A patient journey grouping (e.g., "Surgery")
- **Form** - Data collection form with versioned elements
- **FormDataEntry** - Patient's answers to a form
- **Variable** - Typed data field (NUMBER, TEXT, DATE, CATEGORY, etc.)
- **PROM** - Patient-reported outcome measures (survey forms)
