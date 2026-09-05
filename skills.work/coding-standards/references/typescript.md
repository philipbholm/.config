# TypeScript and validation

- Derive types from schemas, generated GraphQL types, Prisma utilities, and
  existing domain types rather than maintaining parallel shapes.
- Prefer inference, narrowing, discriminated unions, and runtime guards over
  casts. Never use `as any` or `as unknown` to silence a type error.
- Use string unions or const maps instead of TypeScript enums.
- Use Zod at trust boundaries. Owned TypeScript modules use the type system and
  domain checks rather than repeated parsing.
- GraphQL mutation inputs are validated at the resolver boundary before they
  reach application logic.
- Use `z.stringbool()` for environment booleans. Do not use
  `z.coerce.boolean()`.
- A schema default accepts omission explicitly. Tests cover configuration
  defaults and parsing edge cases.
- Prefer required fields. Guard genuinely impossible missing values with a typed
  invariant error rather than a non-null assertion.
- Declare a type after the types on which it depends.
