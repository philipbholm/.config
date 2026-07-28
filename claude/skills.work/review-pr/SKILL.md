---
name: review-pr
description: Use when reviewing a GitHub pull request and posting inline review comments on it
argument-hint: "[pr url | pr number]"
---

If provided link to a PR review that, if not ask for link to PR. Then go through the points below, and leave comments, ideally on the relevant code line if not in mention in a summary.

Be extremely skeptical and critical, provide constructive criticism.

Before reviewing, read the project context — it carries the rules this file does not repeat:
- repo-root `CLAUDE.local.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/testing.md`
- `/Users/philip/.config/dev/feedback/SYNTHESIZED_LEARNINGS.md` — guidelines distilled from earlier reviews of this repo

- Note on every comment that the review was done automatically by claude code
- post only comments that name a concrete problem or suggestion in the changed code
- be relentlessly on the lookout for code that does not need to be there, overengineering and over complication. simplicity is king
- ensure backend test coverage is sufficient
- ensure frontend test coverage is sufficient
- consider if storybook coverage frontend should be improved and if it is sufficient
- for very large PRs, review in file-group passes yourself, delegate only if I ask for it

After submitting, list the comments you posted and use the `open` command to open the URL to the review in my browser so i can verify it.

# pr structure

## title
- the pr title should include a gitmoji

## risk assessment
- consider if the risk assessment is sufficient and in accordance with the sdlc defined in ledidi-monorepo/docs/sdlc

## description
- the pr description should cleary state _why_ something is being done, either self contained or by linking to an issue that is descriptive as to the why

# general
- code comments: ensure code comments have intent and are not redundant/noisy

# testing

- tests should never use arbitrary timeouts etc, always flag those as potential issues
- increasing timeout for test is also a red flag, always falg it as a potential issue
- tests should be as isolated and self contained as possible, some test abstraction is fine (like buildTestApplication), but for the most part we should be really adamant about keeping self made test abstractions to a minimum – tests should ideally be readable from top to bottom without having to invoke code all over the place to understand whats going on
- strive to make test assertions readable

## e2e tests
- we want e2e tests for main code flows, no need to be too detailed

## integration test
- most code paths should be covered by integration tests, both front- and backend.
- when the logic is very heavy we should resort to unit tests

# backend
## integration tests
- It should be a really good reason not to use the `registryTestBuilder` to configure tests, always flag it as a potential issue
- It should be a really good reason to have more than one `withPermission` call in the test setup, always flag it as a potential issue and explicitly have it reviewed
- In general the registryTestBuilder is made to minimize the amount setup not directly relevant to the tests, and e.g. withFormElement should recursively create all dependencies it needs, so look out for redundancy here
- for use cases mutating data we should _at least_ test the following tests: not authorized scenario, main scenario where we test that 1. returns expected data, 2. stores the correct event, 3. stores the new/updated projection
- in addition to this, ensure all of the "main application flows" for a use case is tested, i.e. all various errors that can be thrown should have a test, or other high level logic things. for very specific logic use unit tests to increase coverage.
- To make assertions against things that ends up stored in the DB, use prisma directly, not the application layer (that will require more permissions, which is a no-go)
- IMPORTANT: ALL tests should be fully isolated and not rely on each other's state, they should be able to run in random order
- error assertions should be against error messages, not error types
- ALL tests should have intent and specific purpose, be on the lookout for tests that does not add anything of real value (e.g. "it updates successfully the second time")

## security
- when we use environment variables to avoid security implementations e.g. in testing, it is very important that they are explicitly enabled and not implicitly inferred e.g. by current environment. they MUST be explicit booleans that are enabled to true for us to disable security

## authorization
- ALL authorization logic should run inside the `authorize` part of the use case, and there should be a very good reason for that part to return true, be very critical of this.
- the use case must be wrapped so `authorize` is enforced before `run` (`buildAuthorizedUseCase`). a use case that checks permissions inside `run` instead is a bug, not a style choice
- look for authorization bypass: an early return that skips the check, or data being read before `authorize` has passed
- handlers only extract the authentication context. a permission check in a resolver or gRPC handler is in the wrong layer
- gRPC service-token calls must validate the required scope, not just that a token was present
- permissions are `registries.{registryId}.{object}` for subject `user.{userId}`. check that every available scope identifier is passed, that it is the specific entity being touched, and that read vs write is correct
- reading patient data needs audit logging on the server, and the user-visible result should be conditional on that log succeeding

## event sourcing
- all state changes should happen through event sourcing, be on the lookout for accessing prisma directly in use cases, 99% of the time we should use an event instead

# code style
- dont extract things to a variable declared somewhere else if it is only in use in one place, this is very bad for code readability
- always place utils and sub components UNDER the main component/function returned from the file (e.g. react components frontend or use-cases backend)

# front end

## security
- audit logging and masking of sensitive data have to be enforced on the server. a frontend-only access log, or masking a value the client has already fetched, is not security at all — flag it as critical
- a security-critical mutation must be awaited and its failure must block the action. fire-and-forget or catch-and-continue around one is the same bug

## feature flags
- always include explicit tests for both enabled and disabled for all codepaths related to feature flags

## data fetching and transformation
- ideally we shuold avoid prop drilling as much as possible and rather fetch the data in the component that needs it
- if we need to prop drill, make sure to avoid transforming the data on the way while it is being prop drilled, transforming data while prop drilling makes it very hard to understand the code

## storybook
- for more complex frontend components we want to have exhaustive storybook coverage, primarily to get notified when some aspect of the rendered UI of components we care about change
- for storybook be on the lookout for stories that does not add any value, its no point having a story showing something another story is covering (e.g. a single vs many view if the single view is showing something the many view is already covering)
- dont use dynamic dates, that makes snapshot non-deterministic. its important that all stories rely on static dates, either by hard coding or by mocking new Date so it returns a constant date for the story

## hiding/disabling ui elements
- when disabling an UI element, we should specify a reason to the user why it is disabled (e.g. hovering it should display a tooltip with an explanation)
- we should not hide ui elements because the user lacks permissions, rather it should be disabled

## highly cohesive smart components
- often large react components gets bloated with a lot of shared state, queries etc at the start. Instead of this, consider if we can extract the state, query and callbacks into a separate self contained "smart component"

## form elements

### adding new form elements
- when adding new form elements, make sure that all existing integration tests, e2e tests and storybook coverage is updated appropriately, it is easy to forget

## html
- look for redundant divs and suggest to remove them
- layout should ideally be done either with flex or grid in 90% of the cases, be critical of other ways of laying out html

## general
- all delete operation should have confirmation dialogues. confirm deletion by name for composite objects (e.g. registry, event, form), or just a simple confirm dialog for non-composite objects (e.g. form element, medication)

## tests
- keep mocking to an absolute minimum, always flack a mock as a potential issue.
- always consider adding a msw test or moving the test if you see a mock
- be highly skeptical of (premature) abstractions in tests. its fine with simple helpers to avoid long cumbersome repeated test setup, but it should be minimal and have no logic. we have the test application builders that should do most of the lifting wrt. test setup

## translations
- all frontend text should be translated and available in both norwegian and english

## dates
- in general the rule is to not interfere with dates, just pass the datestring with offset and time zone stuff should just work. always flag quirks with e.g. formatting date sting so it does not include offset

## react
- useEffects are the scourge, we should avoid them at all costs. always flag useEffect usage as a potential error and suggest the alternative approach (unless it is very clear that it is needed, or if it is extracted into a separate hook to encapsulate the nastiness)
- always prefer to instantiate a hook as close to the usage of the hook result as possible, i.e. try to avoid unecessary prop drilling
- variable naming: it is a common mistake to name things what they do in a specific instance instead of what they are, e.g. `const canEdit = permissions.hasPlatformCapabilities`. changing names like this makes the code harder to read, avoid it, just keep calling it hasPlatformCapabilities

## graphql
- ensure all queries and mutations has some error handling, showing an ui error if something goes wrong. we also need to log these errors for alerting purposes
- when making changes to graphql query caching, consider if we should have an integration test to document the intended behaviour

## styling
- all components should use shadcn if available, it should be a very good reason for e.g. an inline styled <input />

## accessibility
- all component should be accessible
- ensure that forms are used everywhere they should be, e.g. in dialogs so that pressing enter works as expected
- ensure autofocus is used in a sensible manner, so the user doesnt have to manually select things e.g. after opening a new page or opening a dialog

## error handling
- we should always indicate an error in the UI if something goes wrong from a query/mutation
- be on the lookout for exception swallowing, all exceptions should either be explicitly handled or thrown

## file size
- once react files goes over 200 loc, consider if it can be split up into smaller more managable files. be pragmatic here, its fine to keep a slighly larger file if it makes sense

# logging
- never both log an error and throw it. mostly we should just throw errors and let them bubble up, they will be logged and mapped to appropriate transit layer errors.
- it is extremely important that we get notified when something we can fix goes wrong, so make sure all logging has the appropriate level. we dont get alerts from warn

# file naming
- ALL new files should be lower-kebab-case named. dont flag an existing file just because it shows up in the diff, only suggest a rename when the PR already rewrites that file substantially

# infrastructure
## github actions
- when a new workflow file is added, check if we have similar files existing. if we do, validate the new file against the previous standard. if its a new file, be critical and flag it for human review
