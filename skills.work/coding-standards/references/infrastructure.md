# Infrastructure and scripts

- A new GitHub Actions workflow follows an existing maintained workflow when
  one exists. A genuinely new workflow needs explicit human review.
- Give workflows and visible jobs descriptive names. Cancel superseded
  validation runs per branch where safe; deployment and migration jobs need
  their own concurrency policy.
- Trace shared build inputs through workflow path filters, inner build gates,
  Docker build contexts, ignore rules, and every `COPY` consumer. A workflow
  starting does not prove the affected image is rebuilt.
- Classify dependencies by actual runtime use. Confirm required modules remain
  installed in the production image after a manifest or lockfile change.
- Validate effective production configuration at startup. Configure independent
  service URLs explicitly instead of deriving one by stripping another's path.
- Infrastructure renames update every consumer atomically. Deployment changes
  account for health checks, generated artifacts, mixed versions, and rollback.
- Shell scripts start with `set -euo pipefail`. Database setup and seed scripts
  use a typed language and the established database client instead of raw shell
  or SQL.
- Wait for each background job and propagate its failure. Starting parallel
  commands followed by a bare `wait` does not prove every command succeeded.
- Seed scripts require the current stack's database URL, fail before writing
  when it is absent, and disconnect clients in `finally`. Synthetic patient
  creation is opt-in rather than the default for an omitted API argument.
- Roll out formatter changes separately from feature work. Apply the chosen
  rule consistently and verify existing rules still run after configuration
  changes.
- AI tools and other source-processing services are external data processors.
  Confirm their retention, hosting, access, and vendor agreement before sending
  source code or sensitive data to them.
