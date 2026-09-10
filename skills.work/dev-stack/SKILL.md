---
name: dev-stack
description: Prepare dependencies and operate the Ledidi development stack. Use when installing workspace dependencies, starting services, preparing backend or E2E tests, verifying in a browser, or changing generated dependencies.
---

# Ledidi development stack

Use `dev stack` instead of `docker compose`. Each worktree owns the ports
rendered in its `AGENTS.md` and `CLAUDE.local.md`; never edit configuration to
reach another stack's ports.

## Prepare dependencies when needed

When setup is needed for checks or a check fails, load `verify-change` for
scope and failure handling.

When package dependencies need installation, run
`dev workspace prepare <workspace> [workspace ...]` for those workspaces.
Use `dev workspace prepare --help` for the command's behavior and workspace
definition. It reinstalls selected workspaces, so reuse a working installation
when package manifests, lockfiles, and the Node/package-manager environment
remain compatible. Missing generated output alone needs generation, not an
install. Service startup is a separate step below.

Before a required type check, inspect its package script and generation
inputs. If the check consumes generated types but does not generate them,
run the workspace's generation script first when the inputs changed or the
generated files' freshness is unknown. For example, shell needs
`npm run generate` before `npm run tsc` in `apps/shell`.

Missing generated fields or exports can mean stale output, not a source
defect. Refresh that output and rerun the failed check before changing source.
Refreshing generated types from local schema files needs no dependency
reinstallation or service startup. If generation fails, report that failure
under `verify-change`.

## Start only what the task needs

| Task | Command |
|------|---------|
| TypeScript, Biome, frontend unit tests | No containers |
| Registries backend suite | `dev stack up postgres -d` |
| Registries Playwright E2E | `dev test e2e -- [Playwright arguments]`; add `--shell` before `--` for shell coverage |
| Direct browser verification | `dev stack up` |

Only three full dev stacks can run at a time. A full stack runs application
services and their dependencies; a database-only stack and the shared admin
mock do not count. Run `dev stack list` before starting application services
through `dev stack up` or `dev test e2e`.

If starting this checkout would exceed the limit, stop the other stack most
likely to be unused without asking. Compare recent session
activity for its checkout, running tests or browser processes, and recent
application requests. Prefer a stack whose session has ended and has no active
tests or browser work. If the evidence is incomplete, choose the other stack
with the least recent signs of use; container age alone is not enough.

Run `dev stack stop` from the selected checkout to preserve its containers and
database volumes. Keep the current task's stack running. Report which stack
you stopped and the evidence for choosing it. Confirm it stopped and repeat
if needed until there is room within the limit, then start the required stack.

For registries browser verification, `dev stack up` starts the registries
services and their dependencies. The command already detaches and waits for
readiness. Add `--include-patient` only when verifying patient flows. For
other applications, name the services required by that browser journey.

For Playwright, ensure the frontend workspace dependencies are available,
including `apps/shell` when using `--shell`; prepare only missing or stale
installations. Confirm the selected spec exists and use a unique filename or
an escaped pattern: bracketed route paths are regular expressions to Playwright.
Use the runner's listing option when selection is uncertain, before starting
services. Run through `dev test e2e` so browser requests
and fixture setup receive the same worktree API URL. The command starts the
backend services and checks GraphQL before Playwright starts its frontend.
Read `dev test --help` for preview ports and argument forwarding.

PostgreSQL alone supports the registries suite. Its Vitest setup generates and
resets `registries-test` through `POSTGRES_URL`. After `dev stack up postgres`, pass
the worktree's `POSTGRES_URL` on the command line. A full `dev stack up` writes
`services/registries/.env.test.local`, so the backend suite then runs with a
plain `npm run test`.

Run suites directly in each workspace with the selection from `verify-change`.
Prefer explicit test files for small edits. Vitest's `--changed <revision>` can
select through the import graph in registries backend and frontend; use the
task's starting revision for follow-ups and the PR base for branch verification.
Inspect an unexpectedly broad selection before running it. `services/codelist`
uses Jest and has no equivalent. Report suites run or blocked.

## Coordinate heavy work

Before a backend run, check for active tests in this worktree and competing
builds or suites on the machine. Run at most one database-resetting test process
per worktree, including commit hooks; parallel processes need separate verified
test databases. Wait for this worktree's dependency installs and service rebuilds
to finish before starting tests that rely on them.

When other heavy jobs are active, start registries Vitest with
`--maxWorkers=2 --minWorkers=1`; use one worker for isolated timeout diagnosis.
Adjust from observed results instead of repeatedly launching the same overloaded
run. Parallelize independent reads and lightweight checks while heavy jobs run.
Coordinate with the owning session before stopping its active tests or changing
its services; the stack-capacity policy above governs idle-stack selection.
These are coordination rules, not an automatic lock or machine-wide scheduler.

Reuse a running Storybook for component verification. A healthy Storybook and
mocked component tests do not require a full application stack.

## Operate the stack

- Backend TypeScript reloads through nodemon and the frontend reloads through
  Vite HMR.
- Generation watchers vary by checkout. Run the matching workflow below after
  schema or generation-input changes.
- Services run in Docker. Do not run `npm run dev` or `npm start`.

| Change to a running stack | Workflow |
|--------|----------|
| Backend `.graphql` schema | Run `npm run generate` in `services/registries`, `./compose-supergraph.sh` in `services/apollo-router`, and `npm run generate` in `apps/registries-frontend`; restart registries, frontend, and router |
| `.proto` | Run `npm run generate-proto` in the owner, generate in every consumer, then restart affected services |
| Prisma schema files | For new schema edits, create and inspect the migration. For incoming changes, apply the existing migrations. Run `dev stack up <service> -d` to refresh image inputs, then use the workspace's generation and migration scripts with this worktree's `POSTGRES_URL` as needed |
| `package.json` | Run `npm install`, then `dev stack up --build <service> -d`; a restart does not install dependencies |

When upgrading a service Docker image for a vulnerability, check whether its
migrator uses the same image.

Before browser verification after a rebase, merge, or branch switch, run
`dev stack up` for the required services even when their containers exist.
Startup checks image inputs against the checkout and rebuilds changed or
unverified images. `dev test e2e` runs this check for its backend services.
Configuration such as `prisma.config.ts` and generation scripts can remain in
the image while schema directories are mounted from the checkout; restarting
alone does not refresh those image files. Use `--build` for changed ignored
build inputs or to request an explicit rebuild.

## Browser verification and diagnosis

For “verify in browser,” start the services selected above if needed, open
the rendered frontend URL, and verify the behavior directly. After starting
a new worktree's browser services, confirm the frontend renders.

Start diagnosis with `docker ps`, then read logs from containers carrying the
current worktree name. Only those containers belong to this environment. A
connection failure means container state, not port configuration.

“An unknown error occurred. Please try again later or contact support.” is
usually a service needing a restart, an unrun migration, or missing
dependencies. Establish the Docker-side cause before changing application
code.

For verification against a seeded registry, read
[Browser verification](references/browser-verification.md). Use it to prove the
requested interaction, including persistence after reload and relevant layouts.
