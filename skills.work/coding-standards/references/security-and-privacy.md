# Security and privacy

Medical and patient data is sensitive. Trace sensitive data from ingestion to
storage, use, disclosure, logging, export, retention, and deletion.

This technical checklist is informed by
[OWASP ASVS 5.0](https://owasp.org/www-project-application-security-verification-standard/),
the [OWASP API Security Top 10](https://owasp.org/API-Security/), and the data
protection principles in
[GDPR Article 5](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:02016R0679-20160504).
It supports code review and does not establish legal compliance.

### Authorization and isolation

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
