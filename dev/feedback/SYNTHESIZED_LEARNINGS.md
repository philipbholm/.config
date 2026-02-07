# Synthesized PR Learnings

Consolidated guidelines from ~120 PR reviews. Duplicates merged, organized by category.

---

## 1. Architecture & Domain Design

### Event Sourcing
- Never use direct database mutations for domain entities; always emit domain events and let projections handle persistence.
- Any new create/update/delete use case must emit domain events and project from those events, consistent with the existing architecture.
- Prefer one domain event per endpoint invocation; if multiple side effects are needed, consider a single composite event.
- When a single user action triggers multiple state-changing events, wrap them in a transaction so the operation either fully succeeds or fully rolls back.
- Document or enforce at the framework level that projection handlers always run inside a transaction.
- When implementing deletion in an event-sourced system, explicitly document what data remains in the event store and ensure the deletion promise to users matches the actual data lifecycle.
- Check event metadata schemas before duplicating fields in event payloads; the field may already exist in event metadata.

### Layered Architecture
- Domain layer types must be self-contained; map between transport (gRPC, REST) types and domain types at the handler boundary. Never import transport-generated types into application code.
- Use architecture-aligned naming (ports, adapters, use cases) consistently rather than generic terms like "dependencies" or "services."
- Place a property on the entity that owns it semantically; avoid deriving it from a sibling entity.
- Keep application composition functions focused -- group related use cases into dedicated composition functions rather than a flat, ever-growing builder.
- When a query spans multiple aggregate boundaries, create a dedicated projection rather than overloading an existing one.
- Presentation logic (sorting for display, formatting) belongs in the frontend, not the backend; the backend returns raw domain data.

### Service Design
- Name services after the specific domain they serve (e.g., `ApprovalService`) rather than generic abstractions (e.g., `TaskService`).
- When two services share domain concepts, delegate operations to the owning service rather than duplicating its models.
- When exposing data from an external domain in your GraphQL schema, wrap it under the existing aggregate root rather than exposing the foreign domain's types directly.
- Keep backend naming domain-neutral -- name types after domain concepts, not frontend UI components.
- Return machine-readable keys/identifiers from the API; perform all i18n/l10n formatting on the client side.
- Before designing a new feature, check if a sibling domain already solved the same problem and follow its pattern.

### Design Patterns
- When there is only one concrete use case, write concrete code for it rather than building an abstraction -- generalize once you have two or three real cases.
- When you know a union type will have multiple variants, structure the shared interface to accommodate all known future variants from the start, even if only one is implemented.
- When a feature will need to generalize, note it in code comments, but do not block shipping on speculative abstractions.
- Avoid recursive types when only one level of nesting is needed.
- Use the dependency object pattern when a constructor or function has more than 4 positional parameters, to prevent ordering mistakes.
- Structure domain models to avoid runtime type switches; if a switch/case on a type discriminator is needed during mapping, consider restructuring so the mapping is type-safe by construction.
- Prefix entity IDs with 3-4 character type identifiers for debugging and cross-service tracing; consider nanoid/cuid instead of raw UUIDs.
- Establish and document a single canonical date/datetime string format for storage and API transport before implementing date-related features.

---

## 2. TypeScript & Type Safety

### Type Derivation
- Use schema inference (e.g., `z.infer<typeof schema>`, `Pick`, Prisma utility types) to derive types from a single source of truth instead of maintaining parallel type definitions.
- Always derive frontend types from generated GraphQL types (using indexed access types) rather than maintaining manual interfaces.
- When working with GraphQL union types, prefer `Extract<UnionType, { __typename: "..." }>` over importing the full generated type.
- Omit explicit type annotations when the compiler can infer the type.
- Before defining a new type, search the codebase for existing shared types that cover the same shape and extend or reuse them.

### Type Safety Practices
- Prefer narrowing, discriminated unions, or schema validation over `as` casts, especially at data boundaries.
- Never use `as` casts to silence type errors; fix the upstream type or add a runtime type guard.
- Use string union types instead of TypeScript enums for fixed sets of values.
- Use `useState<T>()` (which implicitly allows `undefined`) rather than `useState<T | undefined>()`.
- Be aware that GraphQL code generation produces three-valued optionals (`T | undefined | null`); document the convention for how your use cases handle the distinction.
- Always use `===` (strict equality) in TypeScript; configure the linter to enforce this.
- Only introduce a separate interface for a class when you have a concrete need (e.g., multiple implementations, test mocking).

### Zod & Validation
- Always validate GraphQL mutation inputs with Zod at the resolver layer before passing to application logic.
- Validate all external configuration (secrets, env vars, API responses) with a schema validator at the point of ingestion.
- For env var schemas, prefer explicit string-to-type transforms over generic coercion to avoid subtle breakage across library upgrades.
- Never use `z.coerce.boolean()` for environment variables; use `z.stringbool()` which correctly interprets `"false"`.
- When upgrading schema validation libraries, audit every coercion call against the new version's semantics.
- When a schema field has `.default()`, mark it `.optional()` to signal the input may be absent.
- Validate date formats at the Zod schema level in domain events so invalid data never enters the event store.
- When broadening a string validation to accept whitespace, add `.trim()` before the regex check and consider collapsing consecutive whitespace.
- Write unit tests for environment variable schemas, especially boolean defaults and number parsing edge cases.
- Duplicate critical validation rules on both frontend and backend so API consumers who bypass the UI are still subject to data integrity constraints.

---

## 3. Testing

### Test Strategy
- Every new backend operation must ship with at least one integration test covering the happy path and one covering the primary error case.
- Every change to a repository or data-access method must be accompanied by tests that verify the new behavior, even if the change seems small.
- Every use case with an `authorize` step needs at least one test verifying unauthorized users are rejected.
- Write one E2E test per feature for the happy path; cover edge cases and error states with integration tests.
- Prefer integration tests that call the actual service endpoint over tests that directly invoke internal use case functions.
- Complex calculation/transformation logic must have unit tests; reserve integration tests for wiring and database interactions.
- Always write unit tests for pure formatting, utility, and data parsing functions.
- When you create a new utility file with pure evaluation logic, add unit tests in the same PR.
- For every new or modified data field, add at least one test assertion that validates the new expected value or format.
- Security-critical utility functions (auth, session cleanup, security state management) require mandatory unit tests.
- Security-sensitive frontend components (PII masking, auth flows, permission gates) must have unit tests covering state transitions and error paths.
- Test fixtures and seed generators that produce structured data should have their own unit tests.
- Test failure modes of external service calls; simulate failures and verify rollback or graceful degradation.
- When implementing entity deletion, write explicit test assertions for cascade deletion of each related entity type.
- Write resolver-level integration tests for gRPC endpoints to verify the full request/response mapping.

### Test Assertions
- Use `toEqual` with the full expected object shape instead of asserting fields one at a time.
- Use `toEqual` with `expect.any()` matchers for database verification tests to assert the full record shape.
- Always pass the expected error message or class to `.toThrow("specific message")` to ensure the test validates the correct failure mode.
- Integration tests should assert on resulting state (data correctness), not just the absence of errors.
- When testing write operations, add assertions that read back the persisted state from the database.
- When testing audit logs with multiple entries, assert both the count and the chronological order.
- Assert only on properties relevant to the behavior being tested; do not assert on irrelevant fields just because they exist.
- For every uniqueness validation, include a test for duplicate rejection and a test confirming self-update succeeds.
- For reusable UI components that accept async callbacks, include tests for the rejection/error path.

### Test Setup & Organization
- When integration test setup exceeds ~10 sequential calls, extract a builder or fixture utility.
- Hoist shared, invariant test fixtures to `beforeAll`; reserve `beforeEach` for mutable state.
- Scope test setup to the narrowest `describe` block that needs it.
- Name shared test setup variables generically (e.g., `testSetup`, `ctx`) rather than after a specific assertion.
- When a test file exceeds ~300 lines, evaluate splitting it into focused test files.
- Before writing a new test case, confirm it exercises behavior not already covered by existing tests.
- Every test must justify its unique existence -- if you cannot articulate what unique case it validates, remove it.
- For structured test inputs (CSV, JSON), use shared builder utilities or fixture files.
- Only add global test setup when genuinely required; document why each entry is necessary.

### Mocking
- Use MSW to mock GraphQL requests in integration tests rather than creating custom Apollo client mocks.
- Default to not mocking; only introduce mocks when there is a concrete reason.
- When mocking GraphQL responses, use the project's mock builder pattern (e.g., `registriesMocks().withX().apply()`).
- Mock only the specific exports you need for assertions; let everything else use the real implementation.
- When multiple test files need to mock the same service, create a single exported stub with default implementations.
- Never add global error suppression (`process.on('unhandledRejection')`) in test setup files.

### Test Naming & Style
- Write test descriptions in plain English that describe observable behavior.
- Match the test describe block naming convention used in the rest of the codebase.
- Follow the testing-library query priority: `getByRole`, `getByLabelText`, `getByText` over `getByTestId`.

### Test Isolation
- For any destructive operation scoped by namespace/tenant, include a test asserting records in a different namespace remain untouched.
- Always seed at least two parent entities to verify queries correctly scope results.
- Use dynamically assigned ports in integration tests to prevent port collision.

---

## 4. React & Frontend

### State Management
- If a value can be derived from existing state, compute it on render (or `useMemo`) rather than storing in separate state synchronized via `useEffect`.
- Call callbacks directly from event handlers rather than routing them through `useEffect` on derived state.
- Prefer initializing derived state at the point of interaction rather than syncing with `useEffect`, unless the component must react to external prop changes.
- Always await async operations that determine UI state transitions -- never use `void` to discard a promise whose result affects what the user sees.
- Prefer throwing errors over returning `undefined` from helper functions when the caller cannot meaningfully continue without a result.

### Component Design
- Keep reusable components free of layout opinions (flex direction, gaps, margins); let the parent control positioning.
- When adding a replacement component, mark the old one as `@deprecated` in the same PR.
- Only use `React.memo` when profiling identifies a measurable re-render performance issue.
- Never set a default `id` on a reusable component; require callers to provide one explicitly.
- Do not wrap component output in an extra DOM element unless it provides specific styling or semantic purpose.
- When a component supports disabled/preview mode, make interactive callbacks optional rather than forcing no-op functions.
- If adding a feature requires a conditional branch that changes rendering shape, extract a separate component.
- Use typed props for structured content (icons, labels); reserve children for freeform content.
- Components used with Radix `asChild` must spread all remaining props onto the underlying DOM element.
- Use stable, unique identifiers from data as the `key` prop; only fall back to array index for truly static lists.
- When a component has display variants mapping to fundamentally different UI elements, use early returns to render each variant separately.
- When many pass-through props accumulate, refactor to use context, hooks, or self-contained subcomponents.
- Only set `displayName` on components wrapped with `forwardRef` or created via higher-order functions that obscure the original name.
- Before submitting a component refactor, diff old vs. new prop interfaces and verify every previously supported feature is retained or explicitly removed.
- Before merging changes to a shared component, search for all import sites and verify each consumer still renders correctly.
- When borrowing an API design from an external library, document why it fits your use case -- "shadcn does it" is not sufficient justification.
- Check the existing icon library before inlining SVGs; if unavailable, create a named icon component.
- Before creating custom state-management abstractions (e.g., `Loadable`), check whether existing libraries (React Query, Apollo) already provide equivalent functionality.
- When regenerating components from library defaults, verify behavioral customizations (sticky headers, event handlers) are preserved.

### Routing & Navigation
- When a UI has distinct "steps" or "views" with different data needs, model them as nested routes with a shared layout.
- When a page requires data from navigation state or URL params, redirect to a recovery point if the data is absent.
- Use the existing route structure's unauthenticated route support rather than placing routes outside the hierarchy.
- Always use the project's route map utility for navigation paths; never construct route strings by hand in components.
- After changing route structures, search the entire codebase for hardcoded path segments being removed.
- When removing or restructuring navigation UI, verify all viewport sizes (mobile, tablet, desktop) still have navigation access.

### Hooks
- Never add DOM event listeners inside ref callbacks; use `useEffect` with cleanup functions.
- Use React's `useId()` hook for HTML id attributes on dynamically rendered form elements.
- When extracting shared logic into a custom React hook, write dedicated `renderHook` unit tests.
- Extract reusable hooks for common UI patterns (e.g., `useDebouncedValue`).
- Before writing custom storage or utility hooks, check if existing dependencies already provide a battle-tested version.

### Forms
- Collocate mutation/submission logic with the form component that renders the fields.
- When using React keys to reset a form on data load, use the narrowest possible key (typically just the entity ID).
- On input blur, validate and normalize the final value; revert to previous valid value if incomplete.

---

## 5. Tailwind & CSS

- Always write complete, static Tailwind class names; use `clsx`/`cn` with object syntax for conditional classes instead of string interpolation.
- Never inline CSS properties that have a direct Tailwind equivalent.
- Use `size-{n}` for square elements instead of separate `h-{n} w-{n}`.
- Always use Tailwind's built-in spacing scale instead of arbitrary bracket values.
- Use Tailwind's `group` / `group-disabled:` modifiers to style child elements based on parent state.
- Define disabled visual states (opacity, cursor, border color) on the base primitive component.
- Place default styling in shared UI components; only override at the consumption site when documented.
- Remove unnecessary z-index values; only add them when there is a specific layering problem.
- Always wrap popover, dropdown, and tooltip content in a Portal when inside dialogs or stacking contexts.
- Standardize on a single headless UI primitive library (Radix); avoid mixing with HeadlessUI.
- Use `currentColor` or parent design token variables for embedded sub-component colors.
- When restricting Tailwind to a design-system subset, audit all existing class usage first to prevent regressions from removed defaults.
- Do not add class-merging utilities (e.g., `cn` wrapping `tailwind-merge`) until style conflict resolution is a demonstrated, recurring pain point.

---

## 6. GraphQL

### Schema Design
- Store each GraphQL query/mutation in its own file, named after the operation.
- Use GraphQL field aliases when multiple types in a union share the same field name with different semantics.
- Align GraphQL field nullability with how callers are actually expected to use the API.
- Name backend types after domain concepts, not frontend UI components.
- After adding fields to a schema, verify they are forwarded in the resolver, stored by the use case, persisted in the database, and returned in the response mapper.
- After refactoring a resolver to use a mapper function, verify all previously returned fields are still present.
- Align GraphQL schema types directly with domain models (1:1 mapping); do not require fields the domain does not naturally produce.
- Name mutations after their specific bounded context; resist catch-all mutations with generic names like "details" or "data."

### Resolver Patterns
- Extract response-shaping logic from resolvers into dedicated mapper functions.
- Extract GraphQL input transformations into named mapper functions co-located with the resolver.
- Keep resolvers thin: orchestration only, mapping and business logic elsewhere.

### Query Design
- When a page needs related data from multiple entities, create a single backend query rather than chaining multiple queries with skip logic.
- Design GraphQL queries to serve specific UI views rather than forcing the frontend to assemble data from generic endpoints.
- If you find yourself using `skip` to chain queries, consider merging them into a single backend query.

---

## 7. Database & Prisma

### Migrations
- Give each Prisma migration a descriptive name; aim for one migration per PR.
- Squash all feature-branch migrations into one clean migration before merging.
- When adding constraints to existing tables, include a pre-constraint data cleanup step.

### Schema Patterns
- Define Prisma enums for any field with a fixed set of valid values instead of bare `String`.
- Follow Prisma's convention of camelCase relation field names.
- Never leave unexplained or vestigial fields in database schemas.
- PostgreSQL does not consider `NULL = NULL` for unique constraints; either make the column non-nullable or add application-level validation.
- When changing a one-to-one relationship to one-to-many, update the database constraint, Prisma schema, and all query methods together in a single migration.

### Query Patterns
- Use `findFirstOrThrow` / `findUniqueOrThrow` when the record is expected to exist.
- Guard database queries with an early return when the input array is empty.
- Encapsulate "get latest version" logic in a single repository method so callers cannot forget the sort order.
- Use `createMany` for bulk test data setup when ordering is irrelevant.
- When updating multiple related rows, prefer batch operations or document why sequential updates are safe.
- Combine pagination total count as part of the primary data query rather than a separate count query.
- Hoist shared queries above conditional blocks when multiple validations need the same data.

### Upserts & Projections
- Audit upsert operations to ensure write-once fields (creator, creation timestamp) are only set in the create clause, not the update clause.
- Separate insert and update paths in projections to ensure audit fields (`createdByUser`, `createdAt`) are immutable after creation.

### Transactions
- Always wrap multi-table writes that must succeed or fail together in a single transaction.
- For operations that must be all-or-nothing, either pre-scan the entire input or wrap in a transaction that rolls back on failure.
- Flag any changes to the order or structure of database write operations for explicit team review before merging.

### Cleanup
- Always call `prisma.$disconnect()` at the end of standalone scripts and seed files.
- When changing how configuration or secrets are loaded, audit and remove unused SDK dependencies.

---

## 8. Authorization & Security

### Authorization
- Every new backend handler must include an `authorize()` call before performing any data access.
- Always supply every available scope identifier (site, registry, org) to authorization checks.
- Create explicit permission entries for every resource access path, even if the UI doesn't yet expose permission management.
- Any operation that reads from one entity and writes to another must enforce permissions on both sides.
- When adding a new mutation, check whether it applies to multiple entity types and wire authorization for each one.
- Whenever you add a new backend operation, check whether a corresponding scope or permission needs to be registered in infrastructure/auth configuration.
- Use separate context types for authenticated vs. unauthenticated flows so authenticated use cases can rely on auth being present without null checks.
- Batch permission checks across multiple entities rather than looping with individual calls.
- Make conditional permission checks explicit with early-return guards and comments, not inline ternaries.

### Environment & Config Safety
- For security-sensitive runtime guards, whitelist allowed values rather than blocklisting disallowed ones.
- When a missing env var could enable a security-relevant code path, treat `undefined` as disallowed and throw immediately.
- Place environment/safety assertions in constructors of dangerous implementations.
- Set `NODE_ENV` explicitly in all Docker Compose services.
- Any setting that enables PII collection/storage must require explicit opt-in.
- Always default new feature flags to `false` (opt-in, not opt-out).
- Complement runtime environment guards with monitoring/alerting to catch misconfigurations that slip through.

### PII & Compliance
- When an action requires a successful audit log for compliance, make the user-visible state change conditional on the audit log succeeding.
- Never rely on frontend code for security enforcement; implement access logging on the server.
- When designing access control for sensitive data, check applicable regulations before simplifying permission models.
- When adding a new event type that stores multi-record metadata, apply per-record filtering to prevent data leakage.

### Dependency Security
- Before adding a new dependency, check its vulnerability status, maintenance cadence, and npm release history.
- Use `npm audit fix` as the first approach for vulnerability remediation; only resort to manual overrides when necessary.
- Every manual dependency override must include a comment with the CVE reference and removal condition.

---

## 9. Error Handling & Monitoring

### Error Reporting
- Use `captureException` with relevant context (entity ID, attempted action) instead of `console.error` in production code.
- Every `captureException` call should include the entity ID and the user's attempted action.
- Distinguish between expected errors (show user feedback) and unexpected errors (also report to monitoring).
- Either log the error and handle it locally, or throw it for a higher-level handler -- never both.
- Only send unexpected server errors (5xx equivalent) to error monitoring; handle expected client errors in logs/metrics.
- Replace all `console.log` statements in production code with proper error reporting or remove them entirely.

### Error Structure
- Narrow try-catch blocks to the smallest necessary scope; always document the reason for empty catch blocks.
- Add descriptive error messages to every runtime assertion explaining what invariant it guards.
- When suppressing error reporting for a category of errors, document the convention clearly so future error types are handled intentionally.

### Error Types
- Throw `NotFoundError` for missing resources and `NotAuthorizedError` for permission failures -- never conflate the two.
- Use domain-specific error types (e.g., `FailedPreconditionError`) rather than generic `Error`.
- When introducing a new error class, register it in the error serialization layer so its message reaches the client.
- When pre-handler middleware returns structured errors, verify the error formatting pipeline preserves error codes.

### Frontend Error Handling
- Every mutation that affects user data must have visible error handling (toast, alert, inline message).
- In error-recovery test scenarios, assert the error state is visible before testing the recovery action.
- When a page requires data from URL params and it's missing, redirect to a recovery point.
- In catch blocks for unexpected errors, call your error-reporting service rather than relying on `console.error`.

---

## 10. Naming Conventions

### Functions & Methods
- Name conversion functions as `sourceToTarget` (not `mapSourceToTarget`) so they compose cleanly with `.map()`.
- Use verb prefixes matching operation semantics: `get` for guaranteed returns, `find` for optional lookups, `resolve` for transformations, `check` for booleans.
- Name queries by what they return, not what they check.
- Name event handlers to describe their effect (e.g., `toggleSidebarOnBackgroundClick`), not generically.
- When a function exists for a performance reason (like building a lookup map), name it to convey the "why."
- Establish a team convention for event handler naming -- choose either `handle{EventName}` or imperative `{action}` and apply consistently.

### Variables & Fields
- Ensure variable and method names precisely describe what they return.
- Name domain fields based on how the value is used, not what it technically is.
- Prefix boolean props with `is` or `has` (e.g., `isOptional`, `isLoading`).
- Name any prop accepting `React.ReactNode` with PascalCase.

### Enums & Constants
- Use full, unabbreviated words for enum values (e.g., `AVERAGE` over `AVG`).
- Use precise enum values rather than ambiguous ones (e.g., `INCREASE_DOSAGE` vs `CHANGE_DOSAGE`).
- When adding domain-specific enums, document their source (e.g., "from FHIR", "provided by clinical team").
- Cross-reference existing standards (FHIR, competitor products) when introducing domain terminology.

### Files
- Always use kebab-case for file names; rename pre-existing files when substantially modifying them.
- Encode file naming conventions in lint rules so they're enforced automatically.
- Place new scripts in the established scripts directory, not at the project root.

### General
- Match the naming convention already established in surrounding code, even if imperfect -- inconsistency is worse.
- Use consistent naming across the full stack (frontend routes, GraphQL operations, backend domain models).
- After a large rename, grep for the old name in string literals, comments, and error messages.
- If you are already changing a file, fix any nearby naming inconsistencies so the codebase stays internally consistent.

---

## 11. Code Organization

### Imports & Dependencies
- Always use the project's path alias (e.g., `~/`) for imports requiring more than two levels of `../`.
- Merge imports from the same module into a single import statement.
- Import directly from source files; do not create or use barrel files (`index.ts` re-exports) in application code.
- Remove unused imports, dead code, and stale files before review.
- Always place testing libraries in `devDependencies` only.
- Place type-only packages (`@types/*`) in `devDependencies`.
- Do not add utility libraries or wrapper functions until the problem they solve has occurred more than once in practice.

### Code Structure
- Place each use case in a dedicated folder with its own test file.
- Extract each step of a multi-step dialog into its own component file.
- When a single function branches on many type discriminators, extract each branch into its own named function.
- Keep use case `run` functions high-level by extracting data transformation into named helper functions.
- When a conditional branch in a use case exceeds 5-10 lines, extract a descriptively named helper function.
- Use early returns and guard clauses to keep conditional logic flat; avoid nesting if-else more than one level deep.
- Document the boundary between component directories (components/ vs ui/) with purpose, abstraction level, and usage guidance.
- Use domain keys directly as dictionary keys when possible to avoid redundant mapping layers.

### Dead Code & Cleanup
- Remove unused props, imports, variables, and files immediately.
- When moving or refactoring functionality, explicitly delete orphaned files in the same PR.
- After renaming or moving a file, verify the old file is deleted and no imports reference it.
- Delete unused types, interfaces, and abstractions promptly rather than leaving as placeholders.
- Never commit unimplemented stubs or placeholder fields to production code.

### Shared Code
- If the same utility is needed by more than one service, extract it into a shared package.
- When the same logic (like formula parsing) is needed in both frontend and backend, extract to a shared package.
- Define each convention in exactly one place and reference from domain-specific files.
- Co-locate dictionaries with their consuming component; only extract to a shared file when multiple components genuinely share them.
- Before defining a new type, search the codebase for existing shared types that cover the same shape and extend or reuse them.

### Documentation
- Document function contracts, expected formats, and constraints using JSDoc (`/** */`) so they surface in IDE tooltips.
- Document complex workarounds with a code comment explaining the specific problem being worked around.
- Add comments explaining non-obvious filtering logic, especially when the filter relies on domain constraints that may change.

---

## 12. i18n & UI Copy

- Always use translation keys for any text rendered in the UI, never hardcoded strings -- including toast messages, button text, and error messages.
- Only capitalize the first word in UI labels (sentence case), unless it is a proper noun.
- Have native speakers review UI translation strings.
- Never compare domain values against translated strings; only use translated strings for display.
- When refactoring a page into multiple pages, extract shared localization into a common file.
- Include translated UI strings in the initial review request so copy issues surface early, not after approval.
- When fixing a locale-specific formatting bug, search for the same pattern across the codebase and centralize the formatting logic.

---

## 13. HTML & Accessibility

- Use semantic HTML elements (`<p>`, `<fieldset>`, `<legend>`, `<label>`) instead of generic `<span>` or `<div>`.
- Use React's `useId()` for HTML id attributes on dynamically rendered form elements.
- Choose ARIA roles based on their semantic meaning (`progressbar` for loading, `alert` for errors).
- Use `aria-label` for icon-only elements instead of `data-testid`.
- When refactoring component styles, verify all interactive states (disabled, focused, hover, active) remain visually distinct.
- Use skeleton loading states that approximate the shape of the final content.

---

## 14. CI/CD & DevOps

### Docker & Infrastructure
- Verify multi-stage Dockerfile COPY instructions at every stage that needs the files.
- Use host-side orchestration scripts rather than container-mounted Docker sockets.
- Only add CI/CD deployment jobs for environments that are actually provisioned.
- When copying CI workflow templates for new services, audit each job for applicability.

### Dependencies & Config
- Ensure the team uses the same npm version (via `.nvmrc` and `engines`); revert unrelated lock file changes.
- Keep shared AI instruction files lean; use personal local files for individual preferences.
- Treat AI tool configuration changes with the same rigor as CI/CD or infrastructure changes.
- When a tool enforces an opinionated format, either adopt it project-wide or set up a plugin.
- Ensure files end with a single trailing newline; configure editor/linter to enforce.

### Infrastructure
- Before renaming any shared infrastructure resource, audit every consumer and update all references atomically.
- Design infrastructure bootstrapping as explicit, documented prerequisites.
- Defer CI tooling additions until foundational infrastructure is stable.
- Verify infrastructure config (load balancers, health checks, ECS task definitions) before changing how a service exposes health endpoints.
- Return shutdown handles from service initializers; orchestrate graceful shutdown at the top level.
- Align infrastructure patterns across sibling services; diverge only with documented reasons.

---

## 15. PR & Review Process

### PR Scope
- Keep PRs focused on a single concern; split large changes into focused PRs by concern.
- When a feature requires a prerequisite fix, land it as a separate PR first.
- Keep observability changes, security fixes, and formatting changes in separate PRs.
- Submit formatting-only changes as standalone PRs before feature branches.
- For large-scale mechanical refactors, break into logical chunks (renames, formatting, logic) or provide a structured summary.
- When a refactor exceeds roughly 100 files, split it into sequential PRs with independently verifiable scopes (e.g., redirect old routes, then delete dead code, then clean up references).

### Before Review
- Run the linter locally and resolve all warnings before marking a PR as ready.
- Before opening a PR, search the diff for temporary code, debug statements, or unintentional changes.
- Remove auto-generated comments that add no information.
- Audit `package.json` for dependencies added during experimentation but no longer used.
- For styling PRs, attach visual evidence (screenshots or Storybook links).
- Always rebase onto the latest main branch and verify all tests pass immediately before merging.
- When a PR involves file renames that the diff tool may misrepresent, state which files are renames in the PR description.
- Before committing unexpected tool-generated changes, identify why they appeared and document the cause in the PR description.

### Communication
- When reverting or replacing an approach, explain what was tried, why it fell short, and what the replacement provides.
- For features that introduce new domain concepts, open a draft PR or discuss the approach before building the full implementation.
- Before implementing a feature by copying an existing pattern, confirm it's still the preferred approach.
- When a PR includes changes outside the main feature scope, add a brief note explaining why.
- If a PR description says "basically a copy of X implementation," verify X is still the canonical approach.
- When multiple hooks share a name, use explicit re-exports to make the canonical import path unambiguous; verify imports after large file moves.
- Before removing a domain concept, run a codebase-wide search for all related terminology (error messages, comments, test fixtures, route constants, type discriminators) and verify every remaining reference is intentional.

### TODOs & Tracking
- Never commit code with vague TODO comments; either fix it, create a tracked issue, or write an actionable TODO with specific context.
- Every TODO must state what the problem is, why it matters, and what needs to be done.
- If a TODO references future work, create a GitHub issue and reference its number.
- Annotate speculative, experimental, or incomplete features with `@experimental` or `@unstable` and track with an issue.
- Do not commit speculative configuration changes with question-mark comments; validate before merging.

---

## 16. Data Design & Domain Modeling

### Schema Design
- When designing categorical values, plan for multiple representations (display, import, export, translation) from the start.
- When a date field could be ambiguous (data entry date vs observation date), name timestamps explicitly.
- Before adding a new field, validate with stakeholders that its semantics match the user's mental model.
- Use metadata/extension tables for optional, template-driven fields rather than nullable columns.

### Validation & Constraints
- For every new database constraint, enumerate all code paths that write to that table and add explicit validation.
- Exclude the current entity from uniqueness checks during update operations.
- Guard business rules in the use case layer, not in database constraints alone, when rules are conditional.
- When a new entity type can reference its own type, add validation to prevent circular references.
- Enforce uniqueness constraints in the use case layer with typed error codes so the frontend can display specific messages.
- Protect referenced configuration entities from deletion while they are still referenced by other entities.

### Data Handling
- Normalize data at the backend/service layer so it's enforced regardless of ingestion path.
- Resolve internal reference IDs to display values in the projection layer, not the frontend.
- Match your validation schema to the exact field names of the external data source.
- When loading secrets from external stores, remember the value is typically a JSON string that must be parsed before validation.
- Always compare logical values against language-independent constants, not translated strings.
- Use the project's established date library (e.g., luxon) consistently; avoid wrapper utilities that obscure locale handling.
- When building an API that matches records by identifier, document what happens when that identifier is missing.
- Normalize only type-appropriate fields; scope transformations to specific data types and pass type information explicitly.
- Guard against empty input sets in import/batch operations as a valid degenerate case.

---

## 17. Async & Distributed Systems

- When a workflow calls an external service then writes locally, add an idempotency guard.
- Add idempotency key fields to every gRPC request and async event payload that triggers a state mutation.
- For every async event-driven flow, document failure scenarios and their recovery mechanisms.
- Implement periodic reconciliation jobs for eventually consistent architectures.
- When designing pub/sub architectures, document which event types each subscriber filters for.
- When an endpoint copies data between entities, enforce permissions on both source (read) and target (write).
- Validate the entire input before committing partial results in batch operations.

---

## 18. Frontend UX Patterns

- Require explicit user confirmation (typing resource name) for destructive operations that affect multiple entities.
- Every mutation handler must include error handling that displays feedback on failure.
- When auto-detecting format properties (e.g., CSV delimiters), always allow user override.
- Remove or hide UI controls whose selected value is not actually consumed by the application.
- Use existing design system components (e.g., shadcn Badge) instead of crafting custom styled elements.
- Use `useLocalStorage` for persisting UI state (sidebar collapse); avoid cookies for client-only preferences.
- When adding click-to-dismiss behavior on large areas, exclude interactive child elements from the trigger.
- Show useful context (usage counts, status, last-modified dates) in overview tables.
- Validate icon choices communicate the intended meaning by testing with someone unfamiliar with the feature.
- Prefer composition over bloated repository methods; create focused query functions and compose at the use case level.
- Format all numeric values in a table column to the same number of decimal places and use right-alignment for visual comparison.
- Search the codebase for existing UI patterns that solve the same problem before designing a new interaction; prefer consistency over novelty.
- Novel interactions should be treated as experiments with explicit rollback criteria, not permanent features.

---

## 19. Infrastructure & Service Architecture

- Use separate routes/server instances for unauthenticated endpoints rather than making authentication optional on existing routes.
- Apply cross-cutting concerns (authentication, logging) through framework middleware scoped to routes, not conditional logic inside handlers.
- Source map strategy differs between backend and frontend: for backend Node.js services, `--enable-source-maps` is acceptable; for frontend bundles, upload source maps to the APM/error-tracking service.
- When implementing multi-step data insertion flows, evaluate whether batch operations or simpler patterns could replace sequential inserts.
- Include display metadata (labels, data types) alongside raw values when passing data across service boundaries so consuming UIs can render generically.
- Align wrapper function parameter names with external SDK field names, or clearly document the mapping.

---

## 20. Security Testing & Validation

- Regex-based security validation must enumerate all syntactically valid input forms and test each explicitly.
- Strip non-semantic content (comments, string literals) before parsing untrusted structured text with regex.
- Security validation logic must have thorough test coverage including bypass attempts and edge cases.
- Keep security fixes scoped to the specific vulnerability; file separate issues for related protections.

---

## 21. AI-Assisted Development

- Store AI agent instructions in tool-agnostic markdown files (e.g., `AGENTS.md`); symlink for specific tools rather than committing tool-specific rule files as the source of truth.
- Evaluate AI-generated tests for actual value before committing; remove those duplicating existing coverage.
- Configure AI coding assistants to minimize unnecessary comments; review AI output for noise before committing.
- Introduce shared developer tool configurations only after team consensus; keep personal tool preferences out of the repository until adoption is agreed upon.
- Verify data retention policies before adding third-party AI plugins that process source code; confirm hosting providers are covered by existing vendor agreements.
- Document the trust boundary for each external integration -- state which services handle source code and under what agreement.

---

## 22. API Design

- When an API endpoint handles two distinct user journeys, split into separate endpoints or flows.
- Return minimal mutation responses unless the client specifically needs the full data.
- Annotate experimental or unstable API endpoints with `@experimental` or `@unstable`.
- If you accept a value in the schema but don't support it at runtime, either block it at the schema level or document the limitation clearly.
- Colocate pagination logic with the consuming component; move pagination state into the component that renders the paginated data.

---

## 23. Performance Patterns

- When you need to look up items by ID inside a loop, build a `Map` (or object keyed by ID) before the loop instead of using `.find()` or `.filter()` repeatedly to avoid O(n^2) lookups.
- Format output appropriately for the operation type (e.g., integer formatting for COUNT, decimal for AVERAGE).

---

## 24. Shell Scripting & Scripts

- Always start shell scripts with `set -euo pipefail`.
- Write database setup and seed scripts in a typed language with ORM/client support rather than raw shell or SQL.
- Survey the repository for existing scripts that solve the same or a related problem before creating new ones; prefer extending or replacing them explicitly over creating parallel solutions.
