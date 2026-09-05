# Infrastructure and scripts

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
