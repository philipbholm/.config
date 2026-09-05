# Testing

- Most backend behavior is covered through integration tests against the public
  service boundary. Unit tests cover calculation-heavy and combinatorial edge
  cases. E2E tests cover critical user flows.
- Frontend integration tests mock the HTTP boundary with MSW. Code owned by the
  application stays real unless a concrete constraint requires a mock.
- A new backend operation has a happy-path test and its primary error case.
- A use case with authorization has an unauthorized rejection test.
- An event-sourced command test asserts the response, stored event, and
  projection state.
- New or modified fields have an assertion for their expected value and format.
- Security utilities and sensitive UI state transitions have explicit tests for
  failures and bypass attempts.
- Audit-log tests assert the complete entry set and its chronological order.
- Feature-flagged behavior has tests with the flag enabled and disabled.
- A bug fix starts with a test that reproduces the bug and remains as a
  regression test.
- External-service failures test rollback, retry, or graceful degradation.
- Tests are isolated and pass in random order. They do not depend on another
  test's database state, time, random output, or assigned port.
- Require evidence for timeout increases. Wait for observable conditions;
  reject longer delays that merely hide a race.
- Keep setup close to the assertion and use established application builders.
  Flag helpers, wrappers, and custom assertions when they hide the test's intent.
- A test states one unique intent in imperative plain English. Delete a test
  that adds no distinct behavioral coverage.
- Assert meaningful results and persisted state. Require exact assertions when
  unexpected extra results would be a defect; subset matchers are appropriate
  when omitted fields are irrelevant to the behavior under test.
- Tests of conditional narrowing fail when the expected type is absent; they do
  not silently skip the assertion.
- Test files use deterministic dates and seeded random data.
- In registries application-error tests, assert the meaningful error message.
  Avoid an empty `toThrow()` or a second test that checks only the error class
  when the message assertion already proves the case. Test the class separately
  when a distinct public contract depends on that type.
