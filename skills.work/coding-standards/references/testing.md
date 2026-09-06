# Testing

- Most backend behavior is covered through integration tests against the public
  service boundary. Unit tests cover calculation-heavy and combinatorial edge
  cases. E2E tests cover critical user flows.
- Frontend integration tests mock the HTTP boundary with MSW. Code owned by the
  application stays real unless a concrete constraint requires a mock.
- A new backend operation has a happy-path test and its primary error case.
- A use case with authorization has an unauthorized rejection test.
- Exercise denial through the wired application or transport that enforces
  authorization. Calling raw `run` or checking an authorization boolean alone
  does not prove the endpoint rejects access. Isolate grants per actor and test.
- An event-sourced command test asserts the response, stored event, and
  projection state.
- Read the full relevant stored set when checking duplicate events or deletion.
  A query capped at one row cannot prove uniqueness; a getter that hides deleted
  records cannot prove physical removal. Assert new event fields directly when
  a replay fallback could conceal their omission.
- New or modified fields have an assertion for their expected value and format.
- Exercise non-default values, selected-to-cleared transitions, and complete
  label/value pairings. A negative filter test includes data that would leak
  without the filter; empty fixtures cannot establish exclusion.
- Security utilities and sensitive UI state transitions have explicit tests for
  failures and bypass attempts.
- Audit-log tests assert the complete entry set and its chronological order.
- Feature-flagged behavior has tests with the flag enabled and disabled.
- A bug fix starts with a test that reproduces the bug and remains as a
  regression test.
- External-service failures test rollback, retry, or graceful degradation.
- Tests are isolated and pass in random order. They do not depend on another
  test's database state, time, random output, or assigned port.
- Read the global setup before adding MSW lifecycle, cleanup, fake-time, or
  database hooks. Each shared resource has one lifecycle owner; restore test
  overrides even when an assertion fails.
- Before a destructive database reset, verify the dedicated test database and
  current worktree's connection. An arbitrary runtime `POSTGRES_URL` is not
  evidence that the target is disposable.
- Require evidence for timeout increases. Wait for observable conditions;
  reject longer delays that merely hide a race.
- Keep setup close to the assertion and use established application builders.
  Flag helpers, wrappers, and custom assertions when they hide the test's intent.
- Select fixtures by domain name or explicit ID, not array position. Keep
  test-specific dependency behavior local. A helper is justified when it makes
  complex setup clearer; assertions and the behavior under test stay visible.
- Inspect builder dependency and reuse semantics before removing an empty
  builder call or changing defaults. Such a call may create the second entity
  the test needs. Add a required relationship to the shared dependency graph
  when that graph owns its setup.
- Seed otherwise-valid state when testing one failure branch. Grant only the
  permissions the actor needs. In registries, inspect the projection through
  the test ports when a readback use case would require an unrelated permission;
  an existing persisted readback is not inherently insufficient.
- A test states one unique intent in imperative plain English. Delete a test
  that adds no distinct behavioral coverage.
- Assert meaningful results and persisted state. Require exact assertions when
  unexpected extra results would be a defect; subset matchers are appropriate
  when omitted fields are irrelevant to the behavior under test.
- Expected values come from the scenario, not a recomputation with production
  helpers. UI assertions use accessible roles, names, and rendered outcomes;
  icon-library classes and Tailwind substrings do not establish domain state.
- Keep realistic pointer and keyboard behavior in tests. A DOM environment
  limitation can justify a narrow stub, but disabling interaction checks or
  simulating browser layout needs a demonstrated reason.
- When replacing a UI entry point, preserve coverage of the user flow it served.
  Update its test to complete the flow through the new control. A callback-only
  assertion does not replace creation, persistence, and rendering coverage.
- Type MSW GraphQL handlers with generated response and variable types. Test
  resolver mapping through the real GraphQL boundary when schemas or mappers
  change; organize registries transport tests by operation.
- Use the production cache policy when the behavior under test depends on
  caching or refetch. Test changed builders and SQL producers through their
  real output, not only downstream hand-built fixtures.
- Tests of conditional narrowing fail when the expected type is absent; they do
  not silently skip the assertion.
- Test files use deterministic dates and seeded random data.
- In registries application-error tests, assert the meaningful error message.
  Avoid an empty `toThrow()` or a second test that checks only the error class
  when the message assertion already proves the case. Test the class separately
  when a distinct public contract depends on that type.
