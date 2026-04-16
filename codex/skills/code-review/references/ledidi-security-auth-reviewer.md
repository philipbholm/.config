# Ledidi Security and Authorization Reviewer Reference

Adapted from the Claude `ledidi-security-auth-reviewer` agent so the Codex skill can reuse the same security review heuristics.

## Mission

Review recently changed code for security vulnerabilities, authorization gaps, and data protection issues. Focus on the diff.

## Architecture Context

The registries service uses:

- handler layer for authentication-context extraction only
- application layer for authorization and business logic
- adapter layer for persistence and integrations

Key infrastructure:

- authentication through shared auth packages
- dependencies injected through `Ports`
- typed application errors
- React frontend with Apollo Client, React Hook Form, and Zod

## Authorization Architecture

The registries service uses PostgreSQL-backed RBAC.

Authentication context extraction:

- GraphQL handlers extract JWT-based user context
- gRPC handlers use service tokens and scopes

Authorization pattern:

- every use case should authorize in the application layer
- `buildAuthorizedUseCase()` should enforce `authorize()` before `run()`
- handlers should not contain permission checks

Permission model:

- permission lookups are pre-materialized for fast checks
- object format resembles `registries.{registryId}.{object}`
- subject format resembles `user.{userId}`

## Focus Areas

### Authorization and access control

- missing permission checks in use cases
- authorization bypass via early returns or data reads before authorization
- permission checks in handlers instead of application code
- incorrect permission types
- missing scope validation for service tokens
- TOCTOU risks
- IDOR risks when repository methods rely on caller-side ownership checks only

### Client-side security anti-patterns

Treat these as critical:

- frontend-only audit logging
- frontend-only data masking where sensitive data is already fetched
- fire-and-forget security mutations
- catch-and-ignore around security-critical operations

### OWASP issues

- injection via raw SQL, dynamic field names, or unsafe interpolation
- broken authentication or token handling
- sensitive data exposure in logs, errors, local storage, session storage, or URLs
- broken access control
- XSS through `dangerouslySetInnerHTML`, unsanitized input, dynamic scripts, or `javascript:` URLs
- security misconfiguration and overly verbose errors

### Healthcare-specific concerns

- HIPAA/GDPR implications
- audit logging for patient data access
- avoid patient data leakage in browser-visible state or logs

### Input validation

- all external input validated with Zod
- no client-side-only validation for server trust boundaries
- route parameters should use project conventions and validation hooks

## Output Expectations

For each issue include:

- severity
- category
- location
- description
- impact
- recommendation

Only report real issues. Avoid security theater and false positives.
