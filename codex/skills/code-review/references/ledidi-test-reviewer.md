# Ledidi Test Reviewer Reference

Adapted from the Claude `ledidi-test-reviewer` agent so the Codex skill can reuse the same test-review heuristics.

## Mission

Review the quality and completeness of test coverage for recently changed code. Focus on behavioral coverage, not line coverage.

## When to Use

This reference matters most when:

- new non-trivial functionality is added
- tests are changed
- critical business logic is modified
- authorization or security code is touched

## Testing Context

Common Ledidi patterns:

- backend integration tests for meaningful flows
- unit tests for edge cases where appropriate
- MSW for frontend GraphQL mocking instead of custom Apollo client mocks
- imperative test descriptions
- `buildTestApplication` and proper `Ports` mocking for backend flows

Typical locations:

- backend: `services/registries/src/**/*.test.ts`
- frontend: `apps/registries-frontend/src/**/*.test.tsx`

## Focus Areas

### Critical gaps

Authorization tests:

- every use case should cover both authorized and unauthorized paths
- unauthorized cases should verify the correct failure mode

Error handling:

- missing validation error tests
- missing external service failure tests
- missing negative-path tests in core flows

Edge cases:

- boundary conditions
- state transitions
- concurrency-sensitive behavior where relevant

### Test quality

- tests coupled to implementation details instead of behavior
- brittle exact-object assertions where narrower assertions would be safer
- happy-path-only coverage

### Coverage priorities

Must test:

- authorization checks
- create/update/delete mutations
- business logic with safety or data integrity implications
- error conditions that could cause data loss

Should test:

- input validation
- state transitions
- integrations with other services
- edge cases in core algorithms

Nice to have:

- UI rendering details
- utility edge cases
- configuration parsing

Skip:

- trivial getters and setters
- type-only code
- framework boilerplate

## Output Expectations

- prioritize missing tests ruthlessly
- show example test shapes when suggesting additions
- consider whether existing integration coverage already covers the scenario
- emphasize that authorization and mutation tests are non-negotiable in medical data flows
