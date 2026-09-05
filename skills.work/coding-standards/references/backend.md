# Backend and architecture

## Architecture and domain design

- Services use Handler → Application → Adapter layers.
- Map GraphQL, gRPC, HTTP, and external transport types to domain types at the
  handler boundary. Application code does not import generated transport types.
- Keep handlers and resolvers thin. Business rules and domain validation live in
  use cases; adapters own persistence and external integrations.
- Generate identifiers in the use case or domain layer, not the handler.
- Inject ports into use cases. Do not import mutable singletons.
- Put each use case in its own directory with its tests. Shared code sits at the
  narrowest feature or package boundary that has multiple real consumers.
- Use cases read domain state through projections, not `PrismaClient`, except
  for documented static reference tables.
- Domain mutations emit events; projections handle persistence. Do not mutate
  domain tables directly from use cases.
- Check event metadata before duplicating fields in event payloads.

## Backend, APIs, and persistence

- Follow the repository's use-case builder pattern. Do not destructure a use
  case `input`; direct access such as `input.registryId` preserves provenance.
- Throw typed application errors, never plain `Error`. Register new error types
  at every transport serialization boundary.
- Extract request and response mapping into named functions beside the handler.
- GraphQL schema types align with domain models. Keep one named operation per
  `.graphql` file.
- Use a specific query or endpoint for a user flow instead of making clients
  chain generic requests or `skip` states.
- Use `findFirstOrThrow` or `findUniqueOrThrow` when absence is exceptional.
- Guard queries whose `in` input may be empty.
- Route record-scoped queries by the exact record and tenant identifiers. Do not
  return namespace-wide events or rows when the caller requested one record.
- Keep creator and creation time in the create branch of an upsert, never the
  update branch.
- Prisma relation fields start with a lowercase letter.
