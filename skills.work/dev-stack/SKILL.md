---
name: dev-stack
description: Prepare dependencies and operate the Ledidi development stack. Use when installing workspace dependencies, starting services, preparing backend or E2E tests, verifying in a browser, or changing generated dependencies.
---

# Ledidi development stack

Use `dev stack` instead of `docker compose`. Each worktree owns the ports
rendered in its `AGENTS.md` and `CLAUDE.local.md`; never edit configuration to
reach another stack's ports.

## Prepare dependencies when needed

For setup scope and failure handling, follow "Verification and push policy"
in the repository's `AGENTS.md` or `CLAUDE.local.md`.

When package dependencies need installation, run
`dev workspace prepare <workspace> [workspace ...]` for those workspaces.
Use `dev workspace prepare --help` for the command's behavior and workspace
definition. Service startup is a separate step below.

Before a required type check, inspect its package script and generation
inputs. If the check consumes generated types but does not generate them,
run the workspace's generation script first when the inputs changed or the
generated files' freshness is unknown. For example, shell needs
`npm run generate` before `npm run tsc` in `apps/shell`.

Missing generated fields or exports can mean stale output, not a source
defect. Refresh that output and rerun the failed check before changing source.
Refreshing generated types from local schema files needs no dependency
reinstallation or service startup. If generation fails, report that failure
under the repository's verification and push policy.

## Start only what the task needs

| Task | Command |
|------|---------|
| TypeScript, Biome, frontend unit tests | No containers |
| Registries backend suite | `dev stack up postgres -d` |
| Playwright E2E or browser verification | `dev stack up` |

Run `dev stack list` before a full `dev stack up`. Three stacks can run at
once; ask before starting a fourth.

PostgreSQL alone supports the registries suite. Its Vitest setup generates and
resets `registries-test` through `POSTGRES_URL`. After `dev stack up postgres`, pass
the worktree's `POSTGRES_URL` on the command line. A full `dev stack up` writes
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

| Change to a running stack | Workflow |
|--------|----------|
| Backend `.graphql` schema | Run `npm run generate` in `services/registries`, `./compose-supergraph.sh` in `services/apollo-router`, and `npm run generate` in `apps/registries-frontend`; restart registries, frontend, and router |
| `.proto` | Run `npm run generate-proto` in the owner, generate in every consumer, then restart affected services |
| `prisma/schema.prisma` | Create and inspect the migration, apply it, run `npm run generate`, then restart the service; pass this worktree's `POSTGRES_URL` to every database command |
| `package.json` | Run `npm install`, then `dev stack up --build <service> -d`; a restart does not install dependencies |

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
