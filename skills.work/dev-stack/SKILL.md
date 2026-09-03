---
name: dev-stack
description: Operate and diagnose the Ledidi Docker development stack. Use when starting services, preparing backend or E2E tests, verifying in a browser, or changing generated dependencies.
---

# Ledidi development stack

Use `dev` instead of `docker compose`. Each worktree owns the ports rendered in
its `AGENTS.md` and `CLAUDE.local.md`; never edit configuration to reach another
stack's ports.

## Start only what the task needs

| Task | Command |
|------|---------|
| TypeScript, Biome, frontend unit tests | No containers |
| Registries backend suite | `dev up postgres -d` |
| Playwright E2E or browser verification | `dev up` |

Run `dev status` before a full `dev up`. Three stacks can run at once; ask
before starting a fourth.

PostgreSQL alone supports the registries suite. Its Vitest setup generates and
resets `registries-test` through `POSTGRES_URL`. After `dev up postgres`, pass
the worktree's `POSTGRES_URL` on the command line. A full `dev up` writes
`services/registries/.env.test.local`, so the backend suite then runs with a
plain `npm run test`.

Run suites directly in each workspace. `--changed origin/master` narrows
Vitest in `services/registries` and `apps/registries-frontend` through the
import graph. `services/codelist` uses Jest and has no equivalent. Report every
suite run and every suite the active stack could not support.

## Operate the stack

- Backend TypeScript reloads through nodemon and the frontend reloads through
  Vite HMR.
- Generated code never reloads automatically. Run the matching workflow below.
- Services run in Docker. Do not run `npm run dev` or `npm start`.

| Change | Workflow |
|--------|----------|
| Backend `.graphql` schema | Run `npm run generate` in `services/registries`, `./compose-supergraph.sh` in `services/apollo-router`, and `npm run generate` in `apps/registries-frontend`; restart registries, frontend, and router |
| `.proto` | Run `npm run generate-proto` in the owner, generate in every consumer, then restart affected services |
| `prisma/schema.prisma` | Create and inspect the migration, apply it, run `npm run generate`, then restart the service; pass this worktree's `POSTGRES_URL` to every database command |
| `package.json` | Run `npm install`, then `dev up --build <service> -d`; a restart does not install dependencies |

When upgrading a service Docker image for a vulnerability, check whether its
migrator uses the same image.

## Browser verification and diagnosis

For “verify in browser,” start the full stack if needed, open the rendered
frontend URL, and verify the behavior directly. After starting a new
worktree's full stack, confirm the frontend renders.

Start diagnosis with `docker ps`, then read logs from containers carrying the
current worktree name. Only those containers belong to this environment. A
connection failure means container state, not port configuration.

“An unknown error occurred. Please try again later or contact support.” is
usually a service needing a restart, an unrun migration, or missing
dependencies. Establish the Docker-side cause before changing application
code.
