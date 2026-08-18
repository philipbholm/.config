# Testing

## Running Tests

The backend suite needs postgres running; E2E needs the whole stack. Neither
starts on its own — see the container table in
[CLAUDE.local.md](/Users/philip/.config/dev/context/ledidi-monorepo/CLAUDE.local.md).
Frontend unit tests need nothing beyond `setup-stack`.

Tests must use the worktree-specific port via environment variables:

```bash
# Backend tests
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test

# Frontend E2E tests
FRONTEND_BASE_URL="http://localhost:{{FRONTEND_PORT}}" \
E2E_API_URL="http://localhost:{{REGISTRIES_PORT}}/graphql" \
npm run test:e2e:registries
```

A full `dev up` writes `services/registries/.env.test.local` with that same
`POSTGRES_URL`, and the vitest global setup loads it — so the prefix is only
needed when postgres was started on its own.

**Critical rules:**
- Always pass the port via environment variable as shown above
- Never modify hardcoded URLs, `.env` files, or config files to change ports
- Never try standard ports (5432, 3000, 4000) — each worktree has unique ports
- If tests fail to connect, the Docker stack needs attention, not the port config

## File Locations

| Type | Pattern | Framework |
|------|---------|-----------|
| Frontend unit | `src/**/*.test.ts(x)` | Vitest |
| Frontend E2E | `src/app/**/*.spec.tsx` | Playwright |
| Backend integration | `src/**/*.integration.test.ts` | Vitest |

## TDD Workflow

When user says "red/green TDD", run both:
1. Unit tests for the feature
2. Relevant E2E tests

## Test Strategy

Tests matter more than the production code they cover. They are the harness that
makes moving fast with AI possible without getting stuck in the mud.

### Where coverage comes from

| Layer | Carries | Approach |
|-------|---------|----------|
| Backend API tests | Most backend coverage | gRPC/GraphQL/HTTP clients against a running server |
| Backend unit tests | Edge-case-heavy paths | Where an API test per case isn't feasible |
| Frontend integration | Most frontend coverage | Page level; composite-component level when a page is unwieldy |
| E2E | Critical flows | Simple coverage where feasible, deeper for complex areas |
| Storybook | UI regressions | Edge-case states, especially in rarely-visited screens |

**API tests** assert against what the application actually produced — rows in the
database, what a third party was called with, what the server returned. Stubbing
a third-party service is fine. Code internal to the application under test is
not stubbed; that's the part being verified.

**Frontend integration tests** ideally mock only the HTTP layer. Stubbing a
third-party library is a pragmatic exception. Code we own stays real.

**E2E tests** earn their cost on complex flows and on anything React Testing
Library can't reach.

**Storybook** exists to make unintended UI changes visible, particularly in
places nobody looks at often. Components and pages with complex states get
edge-case stories.

### Readability

A test states its intent plainly and can be verified by reading it. Keep setup
as close to the test as possible — ideally everything needed to understand it is
on screen. `buildTestApplication`, `registryTestBuilder` and friends are accepted
exceptions; new abstractions on top of them make tests harder to read, not
easier.

## General Guidelines

- Shared setup in `beforeAll`, assertions in `it` blocks
- Never use `toMatchObject`, `expect.arrayContaining`, or
  `expect.objectContaining` — the pre-commit hook rejects them; use
  `toEqual`/`toStrictEqual`
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
- Feature-flagged code: explicit tests for every affected code path in both the
  enabled and the disabled state
- Bug fixes: a test that reproduces the bug and fails first, then passes. It
  stays in the suite as the regression guard.

## Anti-Patterns

- Inline trivial test helpers; do not extract them. A test that reads top to
  bottom beats a shorter one that hides steps behind a local function — even
  when inlining makes the file longer. Four shapes, all removed in PR review of
  the analysis tests:
  - construction wrappers — `readerFor()` around `new PrismaAnalysisTableReader(...)`
  - field accessors — `rowsOf(result, id)`, `cellsOf`, `dayOf`, `messageOf`
  - custom assertions — `expectRefusal(...)` instead of an inline `expect`
  - single-use builder methods — a `.withGenderOptions()` one test calls
  Not shared helpers, so they stay: a closure passed to
  `expect(() => ...).toThrow()`, and the application builders
  (`buildTestApplication`, `registryTestBuilder`, `buildAnalysisSampleCase`).
- Don't create shared helpers for simple test values — inline them
- Prefer plain variables over trivial helper functions
- Don't test test-only utilities
