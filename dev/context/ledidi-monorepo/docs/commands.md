# Commands Reference

## Development Environment

**Use `dev` instead of `docker compose`** — includes correct compose files.

```bash
dev up                          # Start the full stack (browser work, E2E)
dev up postgres -d              # Start only the database (backend suite)
dev restart <service>           # Restart service
dev up --build <service> -d     # Rebuild (after package.json changes)
dev exec <service> sh           # Shell into container
dev logs -f <service>           # Tail logs
dev ps                          # List containers
```

**Never run:**
- `docker compose up` / `docker compose restart`
- `npm run dev` / `npm start`
- `dev down` / `dev nuke` / `wt-down` — teardown waits until the PR is merged

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

## Verification

The gate is lefthook, run from the monorepo root. It covers all six workspaces —
`services/registries`, `services/patient-bff`, `apps/registries-frontend`,
`apps/patient-frontend`, `apps/shell`, `packages/components` — and skips the ones
your change didn't touch.

```bash
lefthook run pre-commit    # biome/prettier --write, staged tests, matcher ban
lefthook run pre-push      # tsc --noEmit everywhere, prisma + RLS lint
```

Add `--force` when nothing is staged or pushable and you still want the sweep.

Neither hook runs a full suite. For that, let the import graph pick the tests your
change affects:

```bash
npm test -- --changed origin/master
```

`--changed <base>` is a Vitest flag: it selects the test files reachable from the
files that differ from `<base>`. Confirmed in `services/registries` and
`apps/registries-frontend`. `services/codelist` is on Jest — run its suite whole.

---

## Registries Frontend

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

Needs the full stack — `dev up` if it isn't running.

```bash
cd apps/registries-frontend

# All E2E
FRONTEND_BASE_URL="http://localhost:{{FRONTEND_PORT}}" \
E2E_API_URL="http://localhost:{{REGISTRIES_PORT}}/graphql" \
npx playwright test "src/app/.*/registries/.*\.spec\.tsx"

# Single file (replace brackets with .*)
FRONTEND_BASE_URL="http://localhost:{{FRONTEND_PORT}}" \
E2E_API_URL="http://localhost:{{REGISTRIES_PORT}}/graphql" \
npx playwright test "src/app/.*/registries/.*/patients/.*\.spec\.tsx"
```

### Verifying a Change Here

```bash
cd apps/registries-frontend

npm run lint:fix                       # biome
npm run build-ts                       # tsc only — skips the vite build
npm test -- --changed origin/master    # only the unit tests you affected
```

`npm test` pins `--project=unit`. A bare `npx vitest run` here also picks up the
storybook project, which launches a browser.

E2E on top of that, once the full stack is up:

```bash
FRONTEND_BASE_URL="http://localhost:{{FRONTEND_PORT}}" \
E2E_API_URL="http://localhost:{{REGISTRIES_PORT}}/graphql" \
npm run test:e2e:registries
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

### Tests (Vitest)

Needs postgres running — `dev up postgres -d` if the stack is down.

**Always use `{{POSTGRES_PORT}}` via environment variable. Never modify config files to change ports.**

```bash
cd services/registries

# All tests
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test

# Single file
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test -- src/path/to/file.test.ts

# Path substring match
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test -- get-registries

# Test name match
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test -- -t "reorders elements"
```

Vitest takes positional path filters and `-t` for names. There is no
`--testPathPattern` — that was Jest.

### Verifying a Change Here

```bash
cd services/registries

npm run lint:fix        # prisma-lint + biome
npm run build-ts        # tsc

POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries-test" \
npm run test -- --changed origin/master
```

Drop `--changed origin/master` for the whole suite.

---

## Database

```bash
cd services/registries

# Apply migrations
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries" \
npm run migrate

# Reset database (no confirmation needed)
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries" \
npm run migrate-reset -- --force
```

See [workflows.md](./workflows.md#prisma) for full migration workflow.
