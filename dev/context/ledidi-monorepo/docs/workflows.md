# Post-Change Workflows

Follow the workflow matching what you changed. Multiple may apply.

## Changed `.ts` files in a backend service

No action needed. Docker mounts `src/` and nodemon auto-reloads.

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
