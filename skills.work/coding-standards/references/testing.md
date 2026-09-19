# Testing

- Most backend behavior is covered through integration tests against the public
  service boundary. Unit tests cover calculation-heavy and combinatorial edge
  cases. E2E tests cover critical user flows.
- Before adding a case, identify its distinct contract and owner: table
  mechanics, calculation, application/authorization, transport mapping, UI
  interaction, or persisted browser journey. Inspect existing shared coverage.
  Keep representative connections between layers without repeating the full
  calculation or lifecycle matrix at each layer.
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
- Reproduce a bug before fixing it. Keep a regression test when it proves a
  distinct behavior. For low-impact visual fixes, use relevant story or browser
  evidence when a stable automated assertion would not prove the appearance.
  Stories follow the visual-only rule in [Frontend](frontend.md); behavioral
  tests belong in test files.
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
- Keep clicks, queries, waits, and assertions inline in tests. Keep state-setting
  interactions inline in Storybook play functions. Repetition alone does not
  justify extracting a helper. The three-case abstraction rule does not
  override this requirement.
- Before adding an inline MSW GraphQL handler in registries frontend tests,
  inspect `apps/registries-frontend/test-util/registries-mocks.ts` and comparable
  tests. Use existing builders for supported responses. Keep scenario-specific
  timing, request capture, and failures local; reuse shared response factories
  where available. Extend the builder when multiple tests need the same missing
  capability.
- Select fixtures by domain name or explicit ID, not array position. Keep
  test-specific dependency behavior local. Fixture helpers may make complex
  data setup clearer; interactions and assertions stay inline.
- Inspect builder dependency and reuse semantics before removing an empty
  builder call or changing defaults. Such a call may create the second entity
  the test needs. Add a required relationship to the shared dependency graph
  when that graph owns its setup.
- Seed otherwise-valid state when testing one failure branch. Grant only the
  permissions the actor needs. In registries, inspect the projection through
  the test ports when a readback use case would require an unrelated permission;
  an existing persisted readback is not inherently insufficient.
- For transitions, seed the before-state and trigger the actual request or
  mutation. Clearing an already-null field does not prove clearing; installing
  an error handler without making its request does not prove failure handling.
  Establish retirement or deletion in the owning state, not only a fixture ID.
  Use the production query document when testing query compatibility.
- Write application, transport, and UI scenarios as separate named `it` tests,
  with concrete inputs and expected results visible together. Reserve `it.each`
  for compact input/output tables in calculation or validation tests.
- Use hand-checkable numbers and meaningful fixture IDs. Keep input rows and
  expected results together; retain unsorted inputs where ordering is the
  behavior under test. Leave a blank line before each `it` declaration.
- A test proves one behavior and names it in imperative plain English. Split a
  test when its name needs "and" to list what it checks, or when a later
  assertion would still be worth running after an earlier one failed; repeated
  setup is the accepted price. Default-state checks, such as a table or legend
  being absent, get their own test instead of trailing a behavior test. Add a
  case when it proves a distinct contract or failure mode; delete cases that
  add no distinct behavioral coverage. Cover domain behavior at the application
  boundary and transport mapping at the GraphQL boundary without repeating
  the full scenario matrix at both layers. Preserve explicit authorization and
  data-isolation coverage.
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

## Readable scenarios

A calculation fixture can make the arithmetic visible without a remote setup
helper. For example, a grouped-mean case can use this complete input table:

| Group | Measurements | Expected mean |
|-------|--------------|---------------|
| A | 2, 4 | 3 |
| B | 10, 20 | 15 |

For a UI table, locate the named row before asserting its cells. For example,
after rendering an at-risk table with Group A containing 12 patients at time
zero and 8 at the next time point:

```typescript
const groupARow = screen.getByRole("row", { name: "Group A 12 8" });

expect(
  within(groupARow).getAllByRole("cell").map((cell) => cell.textContent),
).toEqual(["12", "8"]);
```

Here Group A is the row header. This assertion keeps the group and its values
together instead of indexing a flat array of cells from the whole table.
