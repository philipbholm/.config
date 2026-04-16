# Ledidi Code Reviewer Reference

Adapted from the Claude `ledidi-code-reviewer` agent so the Codex skill can reuse the same review heuristics.

## Mission

Review recently changed code for correctness, quality, and adherence to Ledidi project patterns. Focus on the diff, not the entire codebase.

## Architecture Context

The registries service follows a 3-layer architecture:

- Handler layer: `src/handlers/` for GraphQL resolvers, gRPC handlers, and HTTP endpoints
- Application layer: `src/application/` for business logic and use cases
- Adapter layer: `src/adapters/` for persistence, projections, and external integrations

Key patterns:

- dependencies via `Ports`, never singleton imports
- `ApplicationError` with `ErrorSubcode`
- one GraphQL operation per `.graphql` file
- Zod for unknown or external input
- no TypeScript enums, prefer string literal types or const maps

## Focus Areas

### Bugs and logic errors

- off-by-one errors, incorrect conditions
- null and undefined handling issues
- race conditions, shared mutable state, incorrect async handling
- memory leaks

### Architecture violations

- Handler -> Application -> Adapter layering breaks
- direct imports instead of DI through `Ports`
- use cases depending on `PrismaClient` directly instead of projections or adapters
- transport-generated types leaking into application code
- domain mutations not emitting required events

### Silent failures and error handling

Look for:

- swallowed errors
- fire-and-forget async operations
- `.catch()` handlers that hide failure
- fallback values that mask a broken query or missing data
- logging without rethrowing when the caller still needs failure semantics

### Code quality

Naming:

- prefer descriptive names over `data`, `info`, `item`, `result`
- function names should describe what they do, not the UI event that triggered them
- `get` means guaranteed, `find` means optional, `resolve` means transform, `check` means boolean

Complexity:

- flatten deep nesting
- remove dead code and unused variables
- delete compatibility hacks for unused behavior
- split functions doing too many unrelated things

TypeScript:

- avoid `as any`, `as unknown`, and gratuitous assertions
- no enums
- dependent types should be declared after their dependencies

Comments:

- stale comments are bugs
- TODO/FIXME needs context
- comments should explain why, not how

## Project Standards

Backend:

- 3-layer pattern
- `Ports` dependency injection
- `ApplicationError` and `ErrorSubcode`
- never throw plain `Error`
- lowercase Prisma relations
- avoid destructuring `input` where project style prefers `input.registryId`

Frontend:

- prefer shadcn/ui before custom components when that is the app convention
- translation keys for all UI text
- `DICTIONARY` near usage when that is the project pattern
- avoid destructuring query objects
- minimize `useEffect`
- use `clsx` and `tailwind-merge` for class composition

General:

- comments explain why
- generous spacing between logical blocks
- Zod only at trust boundaries

## Confidence Filter

Only report issues with high confidence. The original reviewer used a confidence threshold of 80/100. Preserve that bar: do not report speculative issues.

## Output Expectations

- focus on changed code
- include exact file:line references
- provide actionable fixes
- avoid pre-existing issues in unchanged code
