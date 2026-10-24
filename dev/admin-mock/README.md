# admin-mock

Standalone mock of the admin service for local development. It replaces the
real admin service (MySQL, Cognito, SpiceDB, HubSpot, Chargebee) with a small
Node process that serves hardcoded test data.

## What it provides

**gRPC** (`ADMIN_MOCK_GRPC_PORT`, default 50051):

| Method | Behavior |
|--------|----------|
| `GetUsersByIds` | Lookup from in-memory user store |
| `GetUserByEmailAddress` | Lookup by email, or `NOT_FOUND` |
| `GetUserByToken` | Returns the `stubbed-cognito-username` user |
| `ResetUserPassword` | `{ success: true }` |
| `ResetUserMfa` | `{ success: true }` |

**GraphQL** (`ADMIN_MOCK_GRAPHQL_PORT`, default 4000):

| Route | Schema |
|-------|--------|
| `/graphql` | `admin.graphql` — federated subgraph with stub resolvers |
| `/graphql-public` | `admin-public.graphql` — public queries (SSO check, error details) |
| `/health` | `{ "status": "ok" }` |

All resolvers return hardcoded defaults. The 8 test users match
`services/admin/src/test-data/setup-users.ts`.

## How the dev stack runs it

`dev stack up` starts one shared admin mock when registries is among the
services, and every checkout uses it:

| Port | Used by |
|------|---------|
| 4054 (GraphQL) | the registries frontend's default `VITE_ADMIN_GRAPHQL_URI` |
| 50004 (gRPC) | registries, through `ADMIN_SERVICE_GRPC_ADDRESS=localhost:50004` |

It installs `node_modules` on first use and runs the committed `build/`
output. Its log is `~/work/.dev-stacks/.shared/admin-mock.log`, and
`dev stack list` shows whether it runs. It keeps running until the machine
restarts.

## Changing the mock

`build/` is committed, so the stack runs without compiling. After changing
`src/`, rebuild and restart the running mock:

```bash
cd ~/.config/dev/admin-mock
npm run build
kill "$(jq .pid ~/work/.dev-stacks/.shared/admin-mock.json)"
```

The next `dev stack up` starts it again.

## Updating schemas

The `api/` directory contains copies of the real admin schemas. When the admin
service schemas change, copy the updated files:

```bash
cp /path/to/repo/services/admin/api/admin.proto          ~/.config/dev/admin-mock/api/
cp /path/to/repo/services/admin/api/admin.graphql        ~/.config/dev/admin-mock/api/
cp /path/to/repo/services/admin/api/admin-public.graphql ~/.config/dev/admin-mock/api/
```

New queries or mutations may also need resolvers in `src/graphql-server.ts`.

## Updating test users

Edit `src/users.ts`. The user data should match what
`services/admin/src/test-data/setup-users.ts` seeds into the real admin
database.

## Troubleshooting

**GraphQL errors in the frontend:** the mock's schemas may not match the repo.
When the admin service added fields or queries, update the schemas.

**The mock does not start:** read `~/work/.dev-stacks/.shared/admin-mock.log`.
A missing schema file in `api/` is the usual cause.
