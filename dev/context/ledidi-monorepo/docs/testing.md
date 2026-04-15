# Testing

## File Locations

| Type | Pattern | Framework |
|------|---------|-----------|
| Frontend unit | `src/**/*.test.ts(x)` | Vitest |
| Frontend E2E | `src/app/**/*.spec.tsx` | Playwright |
| Backend integration | `src/**/*.integration.test.ts` | Jest |

## TDD Workflow

When user says "red/green TDD", run both:
1. Unit tests for the feature
2. Relevant E2E tests

## General Guidelines

- Shared setup in `beforeAll`, assertions in `it` blocks
- Prefer `toEqual` over `toMatchObject`
- Imperative descriptions: `it("reorders elements", ...)` not `it("should...")`
- Integration tests for backend, unit tests for edge cases
- Prefer integration tests calling service endpoints over invoking use cases directly

## Test Organization

- Order: error case → empty state → with-data → special cases
- Consolidate related assertions into one test unless setup differs
- Assert full response shape, not just one field
- Test intermediate values (e.g., 50%) not just boundaries (0%, 100%)

## Frontend Tests

### MSW Mocking

Use MSW, not custom Apollo client mocks. Use the mock builder pattern:

```typescript
registriesMocks().withX().apply()
```

Type your mocks:

```typescript
import type { GetPatientsQuery, GetPatientsQueryVariables } from "test-util/generated/gql-test-sdk";

TEST_GRAPHQL_API.query<GetPatientsQuery, GetPatientsQueryVariables>("GetPatients", () => { ... })
```

Type mock data with indexed access:

```typescript
const patients: GetPatientsQuery["getPatients"]["patients"] = [...]
```

### Test Setup

Global setup handles server lifecycle. Test files only need:

```typescript
afterEach(() => {
  cleanup();
});
```

Import `server` only when using `server.use(...)` for per-test handlers. Inline handlers in the test body when used once; extract only when shared.

### Path Patterns

- Vitest: literal paths including brackets (`[lang]`)
- Playwright: regex, replace brackets with `.*`

## Backend Tests

### Setup

```typescript
const { application } = await buildTestApplication({
  overridePorts: { emailService: mockEmailService },
});

const context = mockContext({
  userId: "test-user-id",
  allowedScopes: ["registry:read", "registry:write"],
});

const result = await registryTestBuilder(application, context)
  .withRegistry()
  .withPatient()
  .withEpisode()
  .build();
```

### E2E Setup

```typescript
const result = await e2eRegistryTestBuilder(client)
  .withEvent({ repeatable: true })
  .withTextFormElement({ label: "Test Field", variableName: "test_field" })
  .withFormToEvent()
  .withPatientEventEntry()
  .build();
```

## Required Coverage

- New backend operation: happy path + primary error case
- Use case with `authorize()`: unauthorized rejection test
- Event-sourced command: assert event storage, projection state, response
- New/modified field: assertion for expected value/format
- Complex calculations: unit tests
- Security utilities (auth, session, permissions): mandatory unit tests

## Anti-Patterns

- Don't create shared helpers for simple test values — inline them
- Prefer plain variables over trivial helper functions
- Don't test test-only utilities
