# Coding Standards

The shared engineering and review standard for work repositories. This
file lives outside those repositories until the team adopts it there.

These rules are authoritative. Repository context may add stricter rules or
explain how a rule applies to that repository. Tooling owns rules it can enforce
deterministically; PR review should not repeat lint, type, formatting, or build
output.

## Review bar

- Raise a finding only when the changed code contains a concrete problem or a
  specific improvement worth the author's time.
- Security, privacy, test coverage, and test quality do not bend for incomplete
  features. Put incomplete work behind a feature flag.
- Prefer subtraction. Flag unnecessary code, speculative abstraction, and
  complexity that makes the changed behavior harder to verify.
- Fix the root cause and strengthen the test, type, lint rule, or harness that
  could have caught the failure. Do not normalize flaky tests, recurring errors,
  or known anti-patterns as background noise.
- Treat baseline code smells as prompts to investigate, not violations by
  themselves. Repository conventions win over generic advice.
- Review the surrounding code, callers, tests, schemas, and configuration needed
  to establish the consequence. A diff hunk alone is not enough evidence.

## Security and privacy

Medical and patient data is sensitive. Trace sensitive data from ingestion to
storage, use, disclosure, logging, export, retention, and deletion.

This technical checklist is informed by
[OWASP ASVS 5.0](https://owasp.org/www-project-application-security-verification-standard/),
the [OWASP API Security Top 10](https://owasp.org/API-Security/), and the data
protection principles in
[GDPR Article 5](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:02016R0679-20160504).
It supports code review and does not establish legal compliance.

### Authorization and isolation

- Enforce authorization on the server before any protected data access or side
  effect. Frontend visibility and masking are usability controls, not security.
- Every backend handler calls `authorize()` before data access. Use
  `buildAuthorizedUseCase` so authorization cannot be skipped before `run`.
- Put authorization logic in the use case's `authorize` phase. Handlers extract
  authentication context but do not decide permissions.
- Supply every available scope identifier, including site, registry,
  organization, patient, and record identifiers. Check the specific entity and
  the correct read or write action.
- Enforce permissions on both sides of an operation that reads one entity and
  writes or copies data to another.
- Verify object-level and property-level authorization. A caller allowed to see
  one record must not gain access to sibling records or hidden fields.
- Keep tenant and namespace filters in every query, mutation, batch operation,
  background job, cache key, event consumer, and export path.
- gRPC service-token calls validate the required scope, not only the presence of
  a token.
- Use separate context types for authenticated and unauthenticated flows.
- Test unauthorized access and cross-tenant isolation. Destructive operations
  require a test proving that another tenant's records remain unchanged.

### Sensitive-data handling

- Return, expose, log, cache, and export only the sensitive fields required for
  the operation. New collection or storage of personal data is opt-in.
- Keep security enforcement, audit logging, and sensitive-data masking on the
  server. Do not send hidden sensitive values to the client.
- Do not put patient data, credentials, tokens, or secrets in application logs,
  error messages, analytics, tracing, metrics labels, URLs, or source maps.
- Treat third-party services as trust boundaries. Document which data leaves the
  system, why it is required, and the failure and retention behavior.
- Validate and minimize mutation responses, GraphQL selections, DTOs, event
  payloads, and exports. A broad internal model is not an appropriate external
  response by default.
- Preserve purpose and retention boundaries when data is copied, denormalized,
  projected, backed up, or exported.
- A deletion flow states which data is deleted, retained, or recoverable,
  including event-store history, projections, caches, files, and third-party
  copies. User-facing deletion promises must match the implementation.

### Auditability and failure safety

- Reading patient data requires server-side audit logging. When compliance
  requires a successful audit record, the read or visible state change depends
  on that audit write succeeding.
- Await every security-critical mutation. Fire-and-forget and catch-and-continue
  behavior around authorization, audit, masking, session, or security state is a
  defect.
- Audit records identify the actor, action, target, scope, and time without
  copying unnecessary patient data into the log.
- Security controls fail closed. Missing configuration, an unavailable
  dependency, or an unknown state must not enable access.
- Security bypasses for tests or development require an explicit boolean opt-in.
  Never infer a bypass from the environment name or a missing value.
- Security-sensitive feature flags default to disabled and have tests for both
  states.

### Inputs, configuration, and dependencies

- Validate API inputs, environment variables, external responses, uploaded
  files, and imported data at their trust boundary.
- Prefer allowlists for security-sensitive values and paths. Treat `undefined`
  as disallowed when a missing value could enable a sensitive path.
- Test validation with malformed, boundary, and bypass-shaped inputs. Regex
  security checks enumerate every valid representation and reject embedded
  non-semantic content where relevant.
- New dependencies need a clear purpose, active maintenance, acceptable
  vulnerability status, and understood data handling. Manual vulnerability
  overrides name the advisory and their removal condition.
- Secrets stay outside source, generated artifacts, logs, client bundles, and
  test fixtures.

## Correctness and reliability

### Data integrity

- Validate domain invariants in the application layer so every transport and
  ingestion path receives the same protection.
- Normalize data on the server and only for the applicable data type. Do not
  compare domain values with translated display strings.
- Use precise names and formats for dates, times, units, identifiers, missing
  values, and categorical values. Preserve date offsets unless the domain rule
  explicitly converts them.
- Source clinical terminology and categorical values from the agreed domain
  authority, such as FHIR or the clinical team, and preserve that provenance.
- A new or modified field is carried through every required boundary: schema,
  handler, use case, event, persistence or projection, response mapper, client,
  and tests.
- Updating a discriminated union, enum, route, event, or domain term requires a
  search for every consumer and persisted representation.
- Batch operations validate the complete input before committing partial
  results. Empty input is a valid degenerate case unless the domain rejects it.
- Destructive operations account for every related entity and retained copy.
  Referential constraints and application checks must agree.

### Atomicity, concurrency, and distributed work

- Operations described as all-or-nothing use one transaction or complete
  pre-validation before writing.
- Multiple domain events from one action and multi-table writes that form one
  result succeed or fail together.
- Preserve write-once audit fields such as creator and creation time during
  updates and upserts.
- External calls followed by local mutation, retryable commands, gRPC mutations,
  and asynchronous consumers require an idempotency strategy.
- Event-driven flows define duplicate, out-of-order, missing, and failed-event
  behavior. Eventually consistent flows have a recovery or reconciliation path.
- Do not swallow exceptions. Handle an error completely or propagate it to the
  boundary responsible for reporting and recovery.
- A security, audit, persistence, or external-service failure must not leave the
  UI claiming success or the domain in an unacknowledged partial state.

### Compatibility and migrations

- Never edit an applied migration. Use a descriptive migration and keep one
  coherent migration per PR, squashed before merge.
- Adding a constraint to existing data includes a verified cleanup or migration
  path before the constraint is applied.
- Schema relationship changes update constraints, application queries,
  projections, generated types, and callers together.
- Persisted events and data outlive the current code. Event-field changes keep a
  projection fallback or an explicit migration for historical records.
- Switches over persisted data include a runtime failure for unknown values even
  when TypeScript considers the switch exhaustive.
- Public API changes account for existing clients and mixed-version deployment.

### Operability

- Unexpected failures reach monitoring with enough non-sensitive context to
  diagnose the affected action and entity.
- Expected errors produce useful user feedback. Unexpected errors produce user
  feedback and monitoring without exposing internals.
- Log and handle an error locally, or throw it for a higher boundary to log.
  Never do both.
- Use an error level that reaches the required alerting path. A warning is not a
  substitute when the team must act.
- Infrastructure and service shutdown paths finish or reject in-flight work and
  release resources cleanly.

## Architecture and domain design

- Services use Handler → Application → Adapter layers.
- Map GraphQL, gRPC, HTTP, and external transport types to domain types at the
  handler boundary. Application code does not import generated transport types.
- Keep handlers and resolvers thin. Business rules and domain validation live in
  use cases; adapters own persistence and external integrations.
- Generate identifiers in the use case or domain layer, not the handler.
- Inject ports into use cases. Do not import mutable singletons.
- Put each use case in its own directory with its tests. Shared code sits at the
  narrowest feature or package boundary that has multiple real consumers.
- Use cases read domain state through projections, not `PrismaClient`, except
  for documented static reference tables.
- Domain mutations emit events; projections handle persistence. Do not mutate
  domain tables directly from use cases.
- Check event metadata before duplicating fields in event payloads.
- Prefer concrete code until at least two real cases establish a shared shape.
  Remove middle layers that only rename or delegate a call.
- Place behavior and data with the domain concept that owns them. Keep display
  formatting and presentation sorting in the frontend.

## TypeScript and validation

- Derive types from schemas, generated GraphQL types, Prisma utilities, and
  existing domain types rather than maintaining parallel shapes.
- Prefer inference, narrowing, discriminated unions, and runtime guards over
  casts. Never use `as any` or `as unknown` to silence a type error.
- Use string unions or const maps instead of TypeScript enums.
- Use Zod at trust boundaries. Owned TypeScript modules use the type system and
  domain checks rather than repeated parsing.
- GraphQL mutation inputs are validated at the resolver boundary before they
  reach application logic.
- Use `z.stringbool()` for environment booleans. Do not use
  `z.coerce.boolean()`.
- A schema default accepts omission explicitly. Tests cover configuration
  defaults and parsing edge cases.
- Prefer required fields. Guard genuinely impossible missing values with a typed
  invariant error rather than a non-null assertion.
- Declare a type after the types on which it depends.

## Backend, APIs, and persistence

- Follow the repository's use-case builder pattern. Do not destructure a use
  case `input`; direct access such as `input.registryId` preserves provenance.
- Throw typed application errors, never plain `Error`. Register new error types
  at every transport serialization boundary.
- Extract request and response mapping into named functions beside the handler.
- GraphQL schema types align with domain models. Keep one named operation per
  `.graphql` file.
- Use a specific query or endpoint for a user flow instead of making clients
  chain generic requests or `skip` states.
- Use `findFirstOrThrow` or `findUniqueOrThrow` when absence is exceptional.
- Guard queries whose `in` input may be empty.
- Route record-scoped queries by the exact record and tenant identifiers. Do not
  return namespace-wide events or rows when the caller requested one record.
- Keep creator and creation time in the create branch of an upsert, never the
  update branch.
- Prisma relation fields start with a lowercase letter.

## Frontend and user experience

- Use the existing design-system component before creating a custom primitive.
- Render all user-visible text through translation keys in Norwegian and
  English. Compare logic with language-independent values.
- Show a useful error when any query or mutation fails. Report unexpected
  client errors through the configured monitoring service.
- Await async operations that determine visible state. The UI does not advance
  before a required mutation succeeds.
- Compute derived values during render. Use `useEffect` only for synchronization
  with an external system, with cleanup when applicable.
- Instantiate hooks close to where their result is used. Prefer cohesive
  components over state and callback prop chains.
- Do not destructure query or form objects when the repository convention keeps
  their provenance visible.
- Disable unavailable actions and explain why. Do not hide permission-dependent
  actions as a substitute for authorization.
- Destructive actions require confirmation. Require typing the resource name
  when the action affects a composite object or many records.
- Use semantic HTML, associated labels, keyboard-operable forms, sensible focus,
  and meaningful accessible names. Interactive states remain distinguishable.
- Use stable domain identifiers as React keys. Use `useId()` for generated HTML
  identifiers.
- Keep reusable components free of layout opinions. Remove wrapper elements
  without a semantic or styling purpose.
- Preserve all supported states and viewport access when replacing a component
  or restructuring navigation.
- Complex or rarely visited UI states receive Storybook coverage. Stories use
  fixed dates and avoid duplicate states.
- Use static Tailwind class names, the shared spacing scale, and `cn`/`clsx` for
  conditional classes. Portals protect popovers, menus, and tooltips inside
  stacking contexts.
- Keep `DICTIONARY` and Zod schemas at the bottom of the file in which they are
  used.

## Testing

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
- Never use arbitrary timeouts. Increasing a timeout is a reliability finding,
  not a fix for a race.
- Keep setup close to the assertion. `buildTestApplication`,
  `registryTestBuilder`, and established application builders are the shared
  exceptions; avoid local wrappers, field accessors, custom assertions, and
  single-use builder methods.
- A test states one unique intent in imperative plain English. Delete a test
  that adds no distinct behavioral coverage.
- Assert exact meaningful results and persisted state. Avoid subset matchers
  that can pass with unexpected extra data.
- Tests of conditional narrowing fail when the expected type is absent; they do
  not silently skip the assertion.
- Test files use deterministic dates and seeded random data.

## Code style and organization

- Choose descriptive domain names. Avoid generic `data`, `info`, and `item`, and
  spell words out instead of inventing abbreviations.
- Name functions for their result or action: `get` guarantees a result, `find`
  may return none, `resolve` transforms, and `check` answers a boolean.
- Name conversion functions `sourceToTarget`. Boolean props start with `is` or
  `has`.
- Prefer early returns and a flat main path. Extract a branch when its body hides
  the high-level flow.
- Default to no code comments. A comment that remains explains a hidden
  constraint, invariant, or workaround in a complete sentence. It does not
  restate code or point at the current task or a GitHub issue.
- New general files use kebab-case. Hooks and GraphQL operations follow their
  established repository naming conventions.
- Use the repository path alias for deep imports. Import source modules directly
  and do not create barrel files for application code.
- Remove dead code, unused dependencies, abandoned files, debug output, and
  scaffolding before review.
- Do not add a helper, interface, wrapper, dependency, or abstraction for one
  hypothetical consumer.
- Put helpers and supporting components below the main exported function.
- Inline a props type unless it is shared, semantically meaningful, or too large
  to read at the function boundary.
- A file that becomes difficult to navigate should split along cohesive
  responsibilities, not an arbitrary line count.

## Commits and pull requests

- Commit subjects use `<type>: <description>` with `feat`, `fix`, `refactor`,
  `test`, `docs`, or `chore`. Use imperative mood, lowercase after the type, and
  no trailing period. A body explains why, not what the diff already shows.
- Commit and push hooks pass. Fix hook failures instead of bypassing them with
  `--no-verify`.

- A PR title includes a gitmoji. The description explains why the change exists
  under `## Why` and what it changes under `## What`.
- Keep one concern per PR. Separate prerequisite fixes, formatting, security,
  and observability work when they can land independently.
- Aim for fewer than 25 files and 1,500 changed lines. More than 40 files or
  3,000 changed lines requires a concrete reason; first look for a coherent
  split.
- Explain unexpected generated files, lockfile changes, migrations, copied
  patterns, and configuration changes.

## Infrastructure and scripts

- A new GitHub Actions workflow follows an existing maintained workflow when
  one exists. A genuinely new workflow needs explicit human review.
- Infrastructure renames update every consumer atomically. Deployment changes
  account for health checks, generated artifacts, mixed versions, and rollback.
- Production services support graceful shutdown and release standalone database
  clients and other resources.
- Shell scripts start with `set -euo pipefail`. Database setup and seed scripts
  use a typed language and the established database client instead of raw shell
  or SQL.
- AI tools and other source-processing services are external data processors.
  Confirm their retention, hosting, access, and vendor agreement before sending
  source code or sensitive data to them.
