# Correctness and reliability

### Data integrity

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
