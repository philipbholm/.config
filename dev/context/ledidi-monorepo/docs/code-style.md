# Code Style

## General

- Descriptive names, not `data`, `info`, `item`
- Generous newlines between blocks
- Default to no comments. Only add one when strictly necessary to explain _why_ code exists (hidden constraint, subtle invariant, workaround for a specific bug, surprising behavior). Never add comments explaining _what_ the code does. No comments referencing the current task, fix, or callers (e.g. "added for X flow", "used by Y").
- No TypeScript enums — string types or const maps
- Never `as any` or `as unknown`
- `as SomeType` only when TS can't infer but shape is known
- Zod only at trust boundaries
- Never `z.coerce.boolean()` for env vars — use `z.stringbool()`
- One GraphQL operation per `.graphql` file

### Early Returns

Narrow to the expected case and bail out on the rest, so the main path stays at
the top level. This matters most in tests, where a conditional assertion silently
passes when the condition is false:

```typescript
// Correct — the assertion always runs
if (!(error instanceof ValidationError)) {
  throw new Error(`Expected ValidationError, got ${error}`);
}

expect(error.field).toBe("patientId");

// Wrong — passes when error is some other type
if (error instanceof ValidationError) {
  expect(error.field).toBe("patientId");
}
```

### Type Order

Declare dependent types after their dependencies:

```typescript
// Correct
type Column = { id: string; label: string };
type ColumnConfig = { columns: Column[]; defaultSort: Column["id"] };

// Wrong
type ColumnConfig = { columns: Column[]; defaultSort: Column["id"] };
type Column = { id: string; label: string };
```

## File Naming

| Type | Convention | Example |
|------|------------|---------|
| General | kebab-case | `user-details.tsx` |
| Hooks | camelCase + `use` | `useFormId.ts` |
| GraphQL | camelCase | `getForms.graphql` |

## File Bottom

1. Zod schemas + inferred types
2. `DICTIONARY`

## Backend

- Lowercase Prisma relations
- Don't destructure `input` — use `input.registryId`

## Frontend

- Minimize `useEffect` — prefer computed values
- Don't destructure queries: `const userQuery = useUserQuery()`
- Function names describe action: `submitLogin` not `handleClick`
- Conversion functions: `sourceToTarget` not `mapSourceToTarget`
- Prefixes: `get` (guaranteed), `find` (optional), `resolve` (transform), `check` (boolean)

## Props Types

Inline by default:

```typescript
export function Chart({ registryId }: { registryId: string }) {
```

Named type only when:
- Used in multiple places
- Exceeds ~5 properties
- Has semantic meaning

Never create `FooProps` for single use.

- Boolean props: `is` or `has` prefix
