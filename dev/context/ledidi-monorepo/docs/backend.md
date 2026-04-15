# Backend Development

## Services

- **Registries**: Fastify + Apollo Server
- **Codelist**: Express + gRPC (no GraphQL)

## Use Cases

Follow `buildXxxUseCase` builder pattern.

Don't destructure `input` — access `input.registryId` directly for consistent provenance.

## Error Handling

Typed errors in `src/application/errors.ts`:

```typescript
throw new NotFoundError("Registry not found");
```

Rules:
- All errors extend `ApplicationError` with `ErrorSubcode` union types
- **Never throw plain `Error`**
- Use `captureException` with entity ID and action, not `console.error`
- Expected errors → user feedback. Unexpected → monitoring
- Throwing `default` branch in switches on persisted data
- Log and handle locally OR throw — never both

## GraphQL Resolvers

- Thin resolvers: orchestration only, logic in use cases
- Extract response-shaping into mapper functions
- Extract input transforms into named mappers
- After adding fields, verify: resolver → use case → database → mapper
- Schema types align 1:1 with domain models
- Validate mutation inputs with Zod at resolver layer

## Prisma & Database

- `findFirstOrThrow` / `findUniqueOrThrow` when record expected
- Early return when input array is empty
- Wrap multi-table writes in transaction
- Upsert: `creator`, `createdAt` only in create clause
- Lowercase first letter for relations

### Migrations

- Descriptive names
- One per PR
- Squash before merge
- Never edit applied migrations
