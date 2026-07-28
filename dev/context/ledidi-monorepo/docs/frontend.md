# Frontend Development

## Stack

| Concern | Technology |
|---------|------------|
| Styling | Tailwind CSS v4 + `cn` from shadcn |
| Components | shadcn/ui in `src/components/ui/` |
| Forms | React Hook Form + Zod 4 |
| Server state | Apollo Client |
| Local state | React Context |
| Routing | React Router v7 |

## Rules

- shadcn/ui before custom components
- Reusable components: no layout opinions (margins, gaps) — parent controls positioning
- Stable data IDs as React `key`, not array indices
- Translation keys for ALL UI text — never hardcode
- Deletions require confirmation dialog

## File Structure

### Layout Order

1. Imports
2. Local type aliases
3. Exported component
4. Private sub-components (order matches JSX)
5. Helper functions
6. Zod schemas + inferred types
7. `DICTIONARY`

### Component Responsibilities

**Exported component** owns data-fetching and orchestration.

**Sub-components** resolve their own translations via `useLanguage()` + `DICTIONARY[lang]`. Don't pass translated strings as props.

**Exception:** Generic presentational components (e.g., `DatePickerField` with `label` prop) may accept strings when used multiple times with different labels.

**No abstractions for one-off variations.** Similar components with meaningful differences get separate functions.

### Variables

Declare as late as possible — just before first use. Never before an early return that doesn't need it.

**Exception:** Hooks must be called unconditionally at top.

### Directory Organization

Each component in its own subfolder:

```
components/
├── chart-utils.ts                    # Shared, stays flat
├── form-completeness-chart/
│   ├── form-completeness-chart.tsx
│   ├── form-completeness-chart.integration.test.tsx
│   └── getFormCompleteness.graphql
└── section-cards/
    ├── section-cards.tsx
    └── getRegistryOverviewStats.graphql
```

Co-locate `.graphql` with consuming component. Shared utilities stay flat.

## Error Handling

```typescript
import { isFailedPreconditionError, isValidationError } from "~/lib/errors";

if (isFailedPreconditionError(error)) { /* FAILED_PRECONDITION */ }
```

- Every mutation: visible error handling (toast, alert, inline)
- Catch blocks: error-reporting service, not `console.error`

## Dictionaries

- `DICTIONARY` in same file where used — never separate `dictionary.ts`
- At bottom of file
- Function parameters for dynamic values:

```typescript
fullName: (firstName: string, lastName: string) => `${firstName} ${lastName}`
```

## Navigation

- `useXXXId` hooks for route params (`useRegistryId`, `useFormId`)
- `ROUTE_MAP` for navigation paths
- Luxon `DateTime.toLocaleString` for dates
