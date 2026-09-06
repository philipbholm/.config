# TypeScript and validation

- Derive types from schemas, generated GraphQL types, Prisma utilities, and
  existing domain types rather than maintaining parallel shapes.
- Prefer inference, narrowing, discriminated unions, and runtime guards over
  casts. Never use `as any` or `as unknown` to silence a type error.
- Use string unions or const maps instead of TypeScript enums.
- Use Zod at trust boundaries. Owned TypeScript modules use the type system and
  domain checks rather than repeated parsing.
- Validate transport shape at the resolver boundary. Domain constraints,
  including dates, ranges, and answer validity, belong in the use case so
  GraphQL, gRPC, PROM, imports, and agent tools receive the same checks.
- A Zod schema used only by `z.infer` does not validate runtime data. Find the
  actual parse or domain guard before relying on a schema constraint.
- Use `z.stringbool()` for environment booleans. Do not use
  `z.coerce.boolean()`.
- Specify separate behavior for omitted and invalid values. A schema default
  handles omission; it does not supply a fallback for invalid input. Test both
  paths and preserve an established fallback only where the domain permits it.
- Update inputs distinguish omission, clearing with `null` or an empty value,
  and valid zero values. Reject unknown JSON-command keys when stripping them
  would execute a different request; persisted event parsing keeps its required
  historical compatibility.
- Prefer required fields. Guard genuinely impossible missing values with a typed
  invariant error rather than a non-null assertion.
