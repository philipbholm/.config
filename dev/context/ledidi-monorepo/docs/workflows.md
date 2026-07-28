# Post-Change Workflows

Follow the workflow matching what you changed. Multiple may apply.

Every `dev` step below assumes the stack is up. In a worktree running no
containers the reload and restart steps are moot — skip them, and run the
codegen steps, which need no Docker.

## Changed `.ts` files in a backend service

No action needed with the stack up: Docker mounts `src/` and nodemon
auto-reloads.

> Not picking up changes? `dev restart registries`

## Changed `.graphql` schema files {#graphql}

Schema changes ripple through codegen and Registries frontend:

```bash
cd services/registries && npm run generate
cd apps/registries-frontend && npm run generate
dev restart registries
```

## Changed `.proto` files {#proto}

```bash
cd services/registries && npm run generate-proto
# Regenerate in any consuming service
dev restart registries
```

## Changed `prisma/schema.prisma` {#prisma}

Prisma connects from host, so override `POSTGRES_URL`:

```bash
cd services/registries

# Create migration
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries" npm run migrate-create

# Review generated SQL in prisma/migrations/

# Apply migration
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries" npm run migrate

# Regenerate client
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries" npm run generate

dev restart registries
```

### Reset database

Safe to run without confirmation:

```bash
POSTGRES_URL="postgresql://postgres:postgres@localhost:{{POSTGRES_PORT}}/registries" npx prisma migrate reset --force
```

**Always use npm scripts for migrations.** Never run `npx prisma migrate dev` or `npx prisma generate` directly (except reset).

## Changed `package.json` {#dependencies}

```bash
cd services/registries && npm install
dev up --build registries -d
```

`dev restart` won't pick up new dependencies — must rebuild the image.

## Changed frontend files

No action needed. Vite HMR handles it.

## Changed frontend `.graphql` operations

No action needed. `generate-watch` auto-regenerates types.

> Types stale? `cd apps/registries-frontend && npm run generate`

## Upgrading Dockerfiles for a CVE

Check whether the migrator image needs the same bump. It is easy to patch the
service image and leave the migrator on the vulnerable base.

## Verifying a legacy-frontend PR through the shell

`apps/legacy-frontend` is the old "Core" app (projects/datasets/entries), served
into the shell as an iframe. It uses **yarn**, not npm.

To check a legacy PR against **systest**:

```bash
# 1. Legacy dev server, serves PR code on :3000
cd apps/legacy-frontend && yarn start_systest

# 2. Shell with systest Cognito, serves on :3010
cd apps/shell && npm run dev:systest
```

Then open `http://localhost:3010` and log in with a systest account. Legacy
routes render the `:3000` iframe.

**Use `start_systest`, not `yarn start`.** `yarn start` runs `ENV=development`,
which points at a different `/test` backend (`8460znp882/test`) with a different
Cognito client (`2hh28…`) than the shell. Auth still succeeds — project_service
returns 200 — but your account's projects live in the `/prod` systest env, so the
list renders **empty with no error**. `start_systest` targets `vzw57kuda0/prod`
with client `71r4…`, matching the shell and `app-systest.ledidi.no`.

Step 2 requires `apps/shell/.envs/.env.systest.local` (gitignored) containing
`VITE_LEGACY_APP_URL=http://localhost:3000`, so the iframe loads local PR code.

Both ports are pinned by systest CORS: shell on `3010`, legacy on `3000`.

## SpiceDB images without ECR auth

The spicedb images in `services/auth/docker-compose.auth-only.yml` reference ECR
digests that need AWS auth. Without it, swap them for the local tags:

- `ledidi-spicedb:local`
- `ledidi-spicedb-migrator:local`

This is a local-only change — revert it before committing.

---

## What `npm run generate` produces

| Workspace | Output |
|-----------|--------|
| `services/registries` | GraphQL resolver types, Prisma client, gRPC/proto types |
| `services/codelist` | Prisma client, gRPC/proto types |
| `apps/registries-frontend` | Typed GraphQL hooks and types |

**When to run:**
- Changed `.graphql` schema → owning service + `apps/registries-frontend`
- Changed `prisma/schema.prisma` → owning service
- Changed `.proto` → owning service + consumers
