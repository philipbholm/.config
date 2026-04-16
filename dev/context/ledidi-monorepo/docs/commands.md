# Commands Reference

## Development Environment

**Use `dev` instead of `docker compose`** — includes correct compose files.

```bash
dev restart <service>           # Restart service
dev up --build <service> -d     # Rebuild (after package.json changes)
dev exec <service> sh           # Shell into container
dev logs -f <service>           # Tail logs
dev ps                          # List containers
```

**Never run:**
- `docker compose up` / `docker compose restart`
- `npm run dev` / `npm start`

---

## Package Scripts

**Always use npm scripts, not direct tool invocations:**

```bash
# Correct
npm run generate
npm run migrate
npm run test
npm run lint:fix

# Wrong
npx prisma generate
npx jest
npx eslint --fix
```

---

## Registries Frontend

**Never touch `apps/main-frontend/`.** Always use `apps/registries-frontend/`.

```bash
cd apps/registries-frontend

npm run build           # Production build
npm run generate        # Generate GraphQL types
npm run lint:fix        # Fix lint issues
```

### Unit Tests (Vitest)

```bash
cd apps/registries-frontend

npm test                                    # All tests
npm test -- "path/to/file.test.tsx"         # Single file
npm test -- "path/to/directory"             # Directory
```

Vitest accepts literal paths including brackets like `[lang]`.

### E2E Tests (Playwright)

```bash
cd apps/registries-frontend

# All E2E
FRONTEND_BASE_URL="http://localhost:{{FRONTEND_PORT}}" \
E2E_API_URL="http://localhost:{{REGISTRIES_PORT}}" \
npx playwright test "src/app/.*/registries/.*\.spec\.tsx"

# Single file (replace brackets with .*)
FRONTEND_BASE_URL="http://localhost:{{FRONTEND_PORT}}" \
E2E_API_URL="http://localhost:{{REGISTRIES_PORT}}" \
npx playwright test "src/app/.*/registries/.*/patients/.*\.spec\.tsx"
```

### Full Verification

```bash
cd apps/registries-frontend && npm run lint:fix && npm run build && \
FRONTEND_BASE_URL="http://localhost:{{FRONTEND_PORT}}" \
E2E_API_URL="http://localhost:{{REGISTRIES_PORT}}" \
npx playwright test
```

---

## Registries Backend

```bash
cd services/registries

npm run lint:fix        # Fix lint issues
npm run build           # Full build (generate + tsc)
npm run build-ts        # TypeScript only (faster)
npm run generate        # Generate GraphQL, Prisma, gRPC types
```

### Tests (Jest)

**Always use `{{POSTGRES_PORT}}` via environment variable. Never modify config files to change ports.**

```bash
cd services/registries

# All tests
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test

# Single file
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test -- src/path/to/file.test.ts

# Pattern match
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test -- --testPathPattern="get-registries"
```

### Full Verification

```bash
cd services/registries && npm run lint:fix && npm run build-ts && \
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test
```

---

## Database

```bash
cd services/registries

# Apply migrations
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries" \
npm run migrate

# Reset database (no confirmation needed)
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries" \
npx prisma migrate reset --force
```

See [workflows.md](./workflows.md#prisma) for full migration workflow.
