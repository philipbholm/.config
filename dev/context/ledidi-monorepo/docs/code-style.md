# Code Style

## General

- Descriptive names, not `data`, `info`, `item`
- Generous newlines between blocks
- Comments explain _why_, not _what_
- No TypeScript enums — string types or const maps
- Never `as any` or `as unknown`
- `as SomeType` only when TS can't infer but shape is known
- Zod only at trust boundaries
- Never `z.coerce.boolean()` for env vars — use `z.stringbool()`
- One GraphQL operation per `.graphql` file

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
