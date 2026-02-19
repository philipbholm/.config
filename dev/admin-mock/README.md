# admin-mock

Standalone mock of the admin service for local development. Replaces the real admin service (MySQL, Cognito, SpiceDB, HubSpot, Chargebee) with a tiny container that serves hardcoded test data.

## What it provides

**gRPC** (port 50051):

| Method | Behavior |
|--------|----------|
| `GetUsersByIds` | Lookup from in-memory user store |
| `GetUserByEmailAddress` | Lookup by email, or `NOT_FOUND` |
| `GetUserByToken` | Returns the `stubbed-cognito-username` user |
| `ResetUserPassword` | `{ success: true }` |
| `ResetUserMfa` | `{ success: true }` |

**GraphQL** (port 4000):

| Route | Schema |
|-------|--------|
| `/graphql` | `admin.graphql` — federated subgraph with stub resolvers |
| `/graphql-public` | `admin-public.graphql` — public queries (SSO check, error details) |
| `/health` | `{ "status": "ok" }` |

All resolvers return hardcoded defaults. The 8 test users match `services/admin/src/test-data/setup-users.ts`.

## How it works

The mock container runs on a shared Docker network (`admin-mock-net`) with hostname `admin-service.internal` — the same hostname the real admin service uses. The `run-main.sh` script generates a compose override that:

1. Disables `admin` and `mysql` services via `profiles: ["disabled"]`
2. Connects `router` and `registries` to the `admin-mock-net` network

The existing env vars (`ADMIN_SERVICE_GRAPHQL_URL=http://admin-service.internal:4000/graphql`, `ADMIN_SERVICE_GRPC_ADDRESS=admin-service.internal:50051`) resolve directly to the mock container. No env var overrides or port remapping needed.

## First-time setup

```bash
cd ~/.config/dev/admin-mock
docker build -t admin-mock .
docker network create admin-mock-net
docker run -d --name admin-mock --restart unless-stopped \
  --network admin-mock-net --hostname admin-service.internal admin-mock
```

The container uses `--restart unless-stopped` so it survives Docker Desktop restarts.

## After setup

`run-main.sh --up` uses the mock automatically. It checks that the `admin-mock` container is running before starting the stack.

## Rebuilding

After changing source files:

```bash
cd ~/.config/dev/admin-mock
docker rm -f admin-mock
docker build -t admin-mock .
docker run -d --name admin-mock --restart unless-stopped \
  --network admin-mock-net --hostname admin-service.internal admin-mock
```

## Updating schemas

The `api/` directory contains copies of the real admin schemas. If the admin service schemas change, copy the updated files:

```bash
cp /path/to/repo/services/admin/api/admin.proto      ~/.config/dev/admin-mock/api/
cp /path/to/repo/services/admin/api/admin.graphql     ~/.config/dev/admin-mock/api/
cp /path/to/repo/services/admin/api/admin-public.graphql ~/.config/dev/admin-mock/api/
```

Then rebuild (see above). You may also need to update resolvers in `src/graphql-server.ts` if new queries or mutations were added.

## Updating test users

Edit `src/users.ts`. The user data should match what `services/admin/src/test-data/setup-users.ts` seeds into the real admin database.

## Troubleshooting

**`run-main.sh` says admin-mock is not running:**

```bash
docker start admin-mock
```

Or if the container doesn't exist, follow the first-time setup above.

**GraphQL errors in the frontend:**

Check that the mock's schemas match the repo. If the admin service added new fields or queries, the mock schemas need updating.

**Container keeps restarting:**

```bash
docker logs admin-mock
```

Look for startup errors. Common cause: schema files missing from `api/`.
