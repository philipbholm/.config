# Architecture

## Layered Architecture

Services follow a 3-layer pattern:

| Layer | Location | Responsibility |
|-------|----------|----------------|
| Handler | `src/handlers/` | GraphQL resolvers, gRPC handlers, HTTP endpoints |
| Application | `src/application/` | Business logic, authorization |
| Adapter | `src/adapters/` | External integrations, persistence |

Rules:
- Domain types are self-contained
- Map transport types (gRPC, GraphQL) to domain types at handler boundary
- Never import transport-generated types into application code
- Generate IDs in use case/domain layer, not handlers
- Validate domain invariants in use case layer

### Application Layer Organization

Each use case in its own subdirectory. Tests co-located. Shared utilities at feature level.

```
src/application/overview/
├── get-form-completeness/
│   ├── get-form-completeness.ts
│   └── get-form-completeness.integration.test.ts
├── get-patient-stats/
│   ├── get-patient-stats.ts
│   └── get-patient-stats.integration.test.ts
├── overview-projection.ts
└── overview-shared.ts
```

Never place use case files flat in the feature directory.

## Handlers

Registries service has three handler types in `src/handlers/index.ts`:

- **GraphQL** — Fastify + Apollo Server for frontend
- **gRPC** — Service-to-service
- **Cron** — Scheduled tasks

All receive `logger`, `environment`, `application`, and `ports`.

## Dependency Injection

Each service defines `Ports` in `src/ports/index.ts`:

```typescript
type Ports = {
  authentication: EndUserAuthenticationProvider;
  authorizationRepository: AuthorizationRepository;
  registryProjection: RegistryProjection;
  eventStore: EventStore;
};
```

Use cases receive ports as constructor arguments. Never import singletons.

## Projections

Projection classes transform event store data into queryable views:

- Located in `src/application/` (e.g., `registry-projection.ts`)
- Injected into use cases
- Enable efficient queries without re-processing events

Rules:
- Use cases depend on projections, never `PrismaClient`
- Add methods to projections when queries are missing
- Static reference tables (`icd10Code`, `atcCode`) may use `PrismaClient`

## Event Sourcing

- Never use Prisma mutations for domain entities — emit events
- Projections handle persistence
- Route domain reads through projections
- Deprecating an event field? Add projection fallback
- Multiple events from one action? Wrap in transaction
- Check event metadata before duplicating fields in payloads

## Authorization

- Every handler calls `authorize()` before data access
- Supply all scope identifiers (site, registry, org)
- Read-then-write operations enforce permissions on both entities
- Separate context types for authenticated vs. unauthenticated

## Service Communication

| Path | Technology |
|------|------------|
| Service-to-service | gRPC (ts-proto) |
| Frontend-to-backend | GraphQL |
| Auth | JWT (JWKS-verified) |
| Service auth | Separate JWT |
| Authorization | RBAC in PostgreSQL |
