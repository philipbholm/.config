# Backend and architecture

## Architecture and domain design

- Services use Handler → Application → Adapter layers.
- Map GraphQL, gRPC, HTTP, and external transport types to domain types at the
  handler boundary. Application code does not import generated transport types.
- Keep handlers and resolvers thin. Business rules and domain validation live in
  use cases; adapters own persistence and external integrations.
- Generate identifiers in the use case or domain layer, not the handler.
- Inject ports into use cases. Do not import mutable singletons.
- Follow the service's use-case layout. Registries puts each use case in its
  own directory with its tests; studies uses one file per use case. Shared code
  sits at the narrowest boundary with multiple real consumers.
- In registries, use cases read domain state through projections, not
  `PrismaClient`, except for documented static reference tables. Domain
  mutations emit events; projections handle persistence. Other services keep
  their documented repository or event-store pattern.
- Check event metadata before duplicating fields in event payloads.
- Put relationship properties on the relationship. For example, a form is
  repeatable within an event; repeatability belongs to the form/event relation.
- Event projections must reproduce the original decision during replay.
  Carry decision inputs in the event when rereading another projection's
  current state would change that decision; support older event payloads.
- Keep invariant guards needed by independently published or replayed events.
  A similar use-case check does not make the consumer's guard redundant.

## Backend, APIs, and persistence

- Follow the repository's use-case builder pattern. Do not destructure a use
  case `input`; direct access such as `input.registryId` preserves provenance.
- Throw typed application errors, never plain `Error`. Register new error types
  at every transport serialization boundary.
- Map database failures by the specific supported code, such as Prisma `P2025`
  for not-found, and propagate unrelated failures. An explicitly requested
  missing ID follows the not-found contract; an omitted default selection may
  legitimately return none.
- Extract request and response mapping into named functions beside the handler.
- GraphQL schema types align with domain models. Keep one named operation per
  `.graphql` file.
- Response mappers return real values for every promised field. Use a distinct
  domain response shape when data differs; placeholder statuses, zero counts,
  and nulls must not pretend an unfinished field is implemented.
- Use a specific query or endpoint for a user flow instead of making clients
  chain generic requests or `skip` states.
- Use `findFirstOrThrow` or `findUniqueOrThrow` when absence is exceptional.
- Guard queries whose `in` input may be empty.
- Route record-scoped queries by the exact record and tenant identifiers. Do not
  return namespace-wide events or rows when the caller requested one record.
- Prisma relation fields start with a lowercase letter.
