# Review Rules

What to look for when reviewing a pull request in this repo. Shared by the
`review-pr` skill (which posts inline comments) and the `pr-findings` skill
(which reports back instead). Editing this file changes both.

These are the review-specific rules. They do not repeat
[architecture.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md),
[backend.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md),
[code-style.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md) or
[testing.md](/Users/philip/.config/dev/context/ledidi-monorepo/docs/testing.md) —
read those too, along with
[SYNTHESIZED_LEARNINGS.md](/Users/philip/.config/dev/feedback/SYNTHESIZED_LEARNINGS.md),
which distills earlier reviews of this repo.

## Stance

Be extremely skeptical and critical, and constructive with it.

- Be relentlessly on the lookout for code that does not need to be there,
  overengineering and over-complication. Simplicity is king.
- Ensure backend test coverage is sufficient.
- Ensure frontend test coverage is sufficient.
- Consider whether frontend storybook coverage should be improved, and whether
  it is sufficient.
- Only raise a point that names a concrete problem or suggestion in the changed
  code.

# PR structure

## Title

- The PR title should include a gitmoji.

## Risk assessment

- Consider whether the risk assessment is sufficient and in accordance with the
  SDLC defined in `ledidi-monorepo/docs/sdlc`.

## Description

- The PR description should clearly state _why_ something is being done, either
  self-contained or by linking to an issue that is descriptive as to the why.

# General

- Code comments: ensure code comments have intent and are not redundant/noisy.

# Testing

- Tests should never use arbitrary timeouts etc, always flag those as potential
  issues.
- Increasing a timeout for a test is also a red flag, always flag it as a
  potential issue.
- Tests should be as isolated and self-contained as possible. Some test
  abstraction is fine (like `buildTestApplication`), but for the most part we
  should be really adamant about keeping self-made test abstractions to a
  minimum — tests should ideally be readable from top to bottom without having
  to invoke code all over the place to understand what's going on.
- Strive to make test assertions readable.

## E2E tests

- We want e2e tests for main code flows, no need to be too detailed.

## Integration tests

- Most code paths should be covered by integration tests, both front- and
  backend.
- When the logic is very heavy we should resort to unit tests.

# Backend

## Integration tests

- It should be a really good reason not to use the `registryTestBuilder` to
  configure tests, always flag it as a potential issue.
- It should be a really good reason to have more than one `withPermission` call
  in the test setup, always flag it as a potential issue and explicitly have it
  reviewed.
- In general the `registryTestBuilder` is made to minimize the amount of setup
  not directly relevant to the tests, and e.g. `withFormElement` should
  recursively create all dependencies it needs, so look out for redundancy here.
- For use cases mutating data we should _at least_ test the following: the not
  authorized scenario, and the main scenario where we test that it 1. returns
  expected data, 2. stores the correct event, 3. stores the new/updated
  projection.
- In addition to this, ensure all of the "main application flows" for a use case
  are tested, i.e. all the various errors that can be thrown should have a test,
  or other high level logic things. For very specific logic use unit tests to
  increase coverage.
- To make assertions against things that end up stored in the DB, use prisma
  directly, not the application layer (that will require more permissions, which
  is a no-go).
- IMPORTANT: ALL tests should be fully isolated and not rely on each other's
  state, they should be able to run in random order.
- Error assertions should be against error messages, not error types.
- ALL tests should have intent and specific purpose. Be on the lookout for tests
  that do not add anything of real value (e.g. "it updates successfully the
  second time").

## Security

- When we use environment variables to avoid security implementations e.g. in
  testing, it is very important that they are explicitly enabled and not
  implicitly inferred e.g. by the current environment. They MUST be explicit
  booleans that are enabled to true for us to disable security.

## Authorization

- ALL authorization logic should run inside the `authorize` part of the use
  case, and there should be a very good reason for that part to return true. Be
  very critical of this.
- The use case must be wrapped so `authorize` is enforced before `run`
  (`buildAuthorizedUseCase`). A use case that checks permissions inside `run`
  instead is a bug, not a style choice.
- Look for authorization bypass: an early return that skips the check, or data
  being read before `authorize` has passed.
- Handlers only extract the authentication context. A permission check in a
  resolver or gRPC handler is in the wrong layer.
- gRPC service-token calls must validate the required scope, not just that a
  token was present.
- Permissions are `registries.{registryId}.{object}` for subject
  `user.{userId}`. Check that every available scope identifier is passed, that
  it is the specific entity being touched, and that read vs write is correct.
- Reading patient data needs audit logging on the server, and the user-visible
  result should be conditional on that log succeeding.

## Event sourcing

- All state changes should happen through event sourcing. Be on the lookout for
  accessing prisma directly in use cases — 99% of the time we should use an
  event instead.

# Code style

- Don't extract things to a variable declared somewhere else if it is only in
  use in one place. This is very bad for code readability.
- Always place utils and sub-components UNDER the main component/function
  returned from the file (e.g. React components frontend or use cases backend).

# Frontend

## Security

- Audit logging and masking of sensitive data have to be enforced on the server.
  A frontend-only access log, or masking a value the client has already fetched,
  is not security at all — flag it as critical.
- A security-critical mutation must be awaited and its failure must block the
  action. Fire-and-forget or catch-and-continue around one is the same bug.

## Feature flags

- Always include explicit tests for both enabled and disabled for all code paths
  related to feature flags.

## Data fetching and transformation

- Ideally we should avoid prop drilling as much as possible and rather fetch the
  data in the component that needs it.
- If we need to prop drill, make sure to avoid transforming the data on the way
  while it is being prop drilled. Transforming data while prop drilling makes it
  very hard to understand the code.

## Storybook

- For more complex frontend components we want to have exhaustive storybook
  coverage, primarily to get notified when some aspect of the rendered UI of
  components we care about changes.
- For storybook, be on the lookout for stories that do not add any value. There
  is no point having a story showing something another story is covering (e.g. a
  single vs many view if the single view is showing something the many view
  already covers).
- Don't use dynamic dates, that makes snapshots non-deterministic. It's
  important that all stories rely on static dates, either by hard coding or by
  mocking `new Date` so it returns a constant date for the story.

## Hiding/disabling UI elements

- When disabling a UI element, we should specify a reason to the user why it is
  disabled (e.g. hovering it should display a tooltip with an explanation).
- We should not hide UI elements because the user lacks permissions, rather it
  should be disabled.

## Highly cohesive smart components

- Often large React components get bloated with a lot of shared state, queries
  etc at the start. Instead of this, consider if we can extract the state, query
  and callbacks into a separate self-contained "smart component".

## Form elements

### Adding new form elements

- When adding new form elements, make sure that all existing integration tests,
  e2e tests and storybook coverage are updated appropriately. It is easy to
  forget.

## HTML

- Look for redundant divs and suggest removing them.
- Layout should ideally be done either with flex or grid in 90% of the cases. Be
  critical of other ways of laying out HTML.

## General

- All delete operations should have confirmation dialogues. Confirm deletion by
  name for composite objects (e.g. registry, event, form), or just a simple
  confirm dialog for non-composite objects (e.g. form element, medication).

## Tests

- Keep mocking to an absolute minimum, always flag a mock as a potential issue.
- Always consider adding an msw test, or moving the test, if you see a mock.
- Be highly skeptical of (premature) abstractions in tests. It's fine to have
  simple helpers to avoid long cumbersome repeated test setup, but it should be
  minimal and have no logic. We have the test application builders that should
  do most of the lifting wrt. test setup.

## Translations

- All frontend text should be translated and available in both Norwegian and
  English.

## Dates

- In general the rule is to not interfere with dates, just pass the date string
  with offset and time zone stuff should just work. Always flag quirks with e.g.
  formatting a date string so it does not include the offset.

## React

- `useEffect`s are the scourge, we should avoid them at all costs. Always flag
  `useEffect` usage as a potential error and suggest the alternative approach
  (unless it is very clear that it is needed, or if it is extracted into a
  separate hook to encapsulate the nastiness).
- Always prefer to instantiate a hook as close to the usage of the hook result
  as possible, i.e. try to avoid unnecessary prop drilling.
- Variable naming: it is a common mistake to name things what they do in a
  specific instance instead of what they are, e.g.
  `const canEdit = permissions.hasPlatformCapabilities`. Changing names like
  this makes the code harder to read, avoid it, just keep calling it
  `hasPlatformCapabilities`.

## GraphQL

- Ensure all queries and mutations have some error handling, showing a UI error
  if something goes wrong. We also need to log these errors for alerting
  purposes.
- When making changes to GraphQL query caching, consider whether we should have
  an integration test to document the intended behaviour.

## Styling

- All components should use shadcn if available. It should be a very good reason
  for e.g. an inline styled `<input />`.

## Accessibility

- All components should be accessible.
- Ensure that forms are used everywhere they should be, e.g. in dialogs so that
  pressing enter works as expected.
- Ensure autofocus is used in a sensible manner, so the user doesn't have to
  manually select things e.g. after opening a new page or opening a dialog.

## Error handling

- We should always indicate an error in the UI if something goes wrong from a
  query/mutation.
- Be on the lookout for exception swallowing. All exceptions should either be
  explicitly handled or thrown.

## File size

- Once React files go over 200 loc, consider if they can be split up into
  smaller more manageable files. Be pragmatic here, it's fine to keep a slightly
  larger file if it makes sense.

# Logging

- Never both log an error and throw it. Mostly we should just throw errors and
  let them bubble up — they will be logged and mapped to appropriate transit
  layer errors.
- It is extremely important that we get notified when something we can fix goes
  wrong, so make sure all logging has the appropriate level. We don't get alerts
  from warn.

# File naming

- ALL new files should be lower-kebab-case named. Don't flag an existing file
  just because it shows up in the diff, only suggest a rename when the PR
  already rewrites that file substantially.

# Infrastructure

## GitHub Actions

- When a new workflow file is added, check if we have similar files existing. If
  we do, validate the new file against the previous standard. If it's a new
  file, be critical and flag it for human review.
