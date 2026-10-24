---
name: dev-stack
description: Prepare dependencies and operate the Ledidi development stack. Use when installing workspace dependencies, starting services, preparing backend or E2E tests, verifying in a browser, or changing generated dependencies.
---

# Ledidi development stack

`dev stack` runs this checkout's services as processes on this Mac. All
checkouts share one PostgreSQL on localhost:5432, where each checkout has its
own databases. Each worktree owns the ports rendered in its `AGENTS.md`; reach
services only through those ports.

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
| TypeScript, Biome, frontend unit tests | No services |
| Registries backend suite | `dev stack up postgres` |
| Registries Playwright E2E | `dev test e2e -- [Playwright arguments]`; add `--shell` before `--` for shell coverage |
| Direct browser verification | `dev stack up` |

Worktree stacks take slots 1-9. When every slot holds a running stack,
`dev stack up` fails. Then stop the other stack most likely to be unused,
without asking: compare recent session activity for its checkout, running
tests or browser processes, and recent application requests. Run
`dev stack down` from that checkout; its databases stay. Report which stack
you stopped and why. A background job also stops stacks that have been idle
for two hours.

For registries browser verification, `dev stack up` starts registries and
its frontend and waits for readiness. A new checkout gets a database copied
from a seeded template, so the Analysis test registry is already there. Name
`codelist` as well when the journey needs patient identity data.

For Playwright, ensure the frontend workspace dependencies are available,
including `apps/shell` when using `--shell`; prepare only missing or stale
installations. Confirm the selected spec exists and use a unique filename or
an escaped pattern: bracketed route paths are regular expressions to Playwright.
Use the runner's listing option when selection is uncertain, before starting
services. Run through `dev test e2e` so browser requests
and fixture setup receive the same worktree API URL. The command starts the
backend services and checks GraphQL before Playwright starts its frontend.
Read `dev test --help` for preview ports and argument forwarding.

PostgreSQL alone supports the registries suite. `dev stack up postgres` writes
`services/registries/.env.test.local`, which points the suite at this
checkout's own test database, so it runs with a plain `npm run test`. Its
Vitest setup drops and recreates that database on every run.

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
test databases. Wait for this worktree's dependency installs and service restarts
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

- Start, stop and restart services through `dev stack`; it owns their ports,
  databases and logs. `dev stack ps` shows them and `dev stack logs <service>`
  prints a log.
- Backend TypeScript reloads through nodemon and the frontend reloads through
  Vite HMR.
- Generation watchers vary by checkout. Run the matching workflow below after
  schema or generation-input changes.

| Change to a running stack | Workflow |
|--------|----------|
| Backend `.graphql` schema | Run `npm run generate` in `services/registries` and in `apps/registries-frontend`, then `dev stack restart` |
| `.proto` | Run `npm run generate-proto` in the owner, generate in every consumer, then restart affected services |
| Prisma schema files | For new schema edits, create and inspect the migration. For incoming migrations, `dev stack restart registries` applies them |
| `package.json` or lockfile | `dev stack up`; it reinstalls dependencies that no longer match the lockfile and restarts the affected services |

After a rebase, merge, or branch switch, list the incoming files with
`git diff --name-only ORIG_HEAD HEAD` (or the previous head after a branch
switch). Run `dev stack up` when that list touches a lockfile, and
`dev stack restart registries` when it touches Prisma migrations. Otherwise
keep the running services: mounted source reloads through nodemon and Vite,
and the table above covers schema and `.proto` changes.

## Browser verification and diagnosis

For “verify in browser,” start the services selected above if needed, open
the rendered frontend URL, and verify the behavior directly. After starting
a new worktree's browser services, confirm the frontend renders.

Start diagnosis with `dev stack ps`, then `dev stack logs <service>`. Only
this checkout's services belong to this environment. A connection failure
means service state, not port configuration.

“An unknown error occurred. Please try again later or contact support.” is
usually a service needing a restart, an unrun migration, or missing
dependencies. Establish the service-side cause before changing application
code.

For verification against a seeded registry, read
[Browser verification](references/browser-verification.md). Use it to prove the
requested interaction, including persistence after reload and relevant layouts.
