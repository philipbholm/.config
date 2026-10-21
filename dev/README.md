# Dev Scripts

Development commands for checkouts, package workspaces, stacks and agent tooling.

## Available Commands

Start with `dev --help`. Commands follow `dev <thing> <action>`; each group and
action supports `--help` without installing dependencies, starting services,
writing configuration, or removing data. The help text owns command usage.

A **checkout** is the main Git checkout or a worktree. A **workspace** is a
directory with its own `package.json`. A **stack** is the checkout's service processes
and their saved state.

There is no lint/build/test wrapper here. The monorepo's own `lefthook.yml` gates all six workspaces (services/registries, services/patient-bff, apps/registries-frontend, apps/patient-frontend, apps/shell, packages/components) on commit; for ad-hoc runs, call the underlying commands (`npm run build-ts`, `npx vitest run`, `npx biome check`) from the workspace you changed.

The [dev-stack skill](../skills.work/dev-stack/SKILL.md) owns the setup policy
and the recipes for GraphQL, proto, Prisma, and dependency changes.

`dev context render` updates only the current Ledidi checkout. Use
`--all-worktrees` to update the main checkout and all registered worktrees.
`dev agent-config apply --profile work` selects machine-wide work configuration
explicitly; it is independent of repository context rendering.

`dev context show` reports the command's checkout, branch, saved stack slot,
rendered endpoints, and installed instruction and skill paths. It shows disk
state; an existing conversation may still carry earlier instructions.
`dev context check` checks the current Ledidi checkout's two rendered files,
global instruction links, shared skill installations, and explicit skill/document
references. It returns 1 for stale or broken context without repairing it.
Use `dev context render` to refresh rendered instructions after inspecting a failure.

`dev session search` searches user messages in local Claude Code and Codex logs.
It includes archived Codex sessions and worktrees, skips injected context and
sub-agent prompts, and collapses identical conversation copies across harnesses.
Results include the session ID, timestamp, recorded branch, checkout, and a
transcript path with a line number. `--branch` uses recorded metadata and excludes
messages where the branch was not recorded. `--ticket` matches a number or slug
in the user message; it does not query the tracker. Date filters are inclusive.

```bash
dev session search 'dashboard' --repo ~/work/ledidi-monorepo --since 2026-09-01
dev session search --ticket 42 --harness codex --json
dev context show --json
dev context check
```

All commands are available to Claude Code, Codex, Cursor Agent, and terminals
through the installed `dev` entrypoint. Session search reads Claude Code and
Codex formats only; Cursor transcript parsing is not supported. Historical
conversation text is evidence, not current instructions or authorization.
The search is local and creates no transcript cache.

Validate setup scope without installing dependencies or starting services:

```bash
node --test dev/tests/*.test.mjs
python3 -B dev/tests/session-search.test.py
python3 -B dev/tests/stack.test.py
python3 -B dev/tests/test-e2e.test.py
```

## `dev stack` — Unified Dev Stack Manager

Run registries Playwright tests through `dev test e2e`:

```bash
dev test e2e --shell -- dashboard/dashboard.spec.tsx --workers=1
dev test e2e -- --project=chromium
```

Prepare frontend dependencies first (`apps/registries-frontend`, and `apps/shell`
for shell tests). The command starts the backend services, supplies matching API
URLs to the browser and fixture setup, and checks GraphQL before frontend startup.
Preview ports must be free; `dev test --help` lists their allocation.

`dev stack` runs a checkout's services as processes on this Mac. No Docker is
involved. `dev stack --help` lists the actions.

### Shared services

| Service | Where | Started by |
|---------|-------|------------|
| PostgreSQL 17 (Homebrew `postgresql@17`) | localhost:5432, data in `~/work/.dev-stacks/.shared/postgres` | the first `dev stack up` |
| Admin mock (`dev/admin-mock`) | GraphQL :4054, gRPC :50004 | `dev stack up` of registries |

Both keep running until the machine restarts. The PostgreSQL cluster runs with
`fsync`, `synchronous_commit` and `full_page_writes` off: its data is
disposable, and migrations and test resets run faster without them.

### Per-checkout services

| Service | Base port | Command it runs |
|---------|-----------|-----------------|
| `registries` | GraphQL 4006, gRPC 50006 | `npm run dev` in `services/registries` |
| `registries-frontend` | 3003 | `npm run generate`, then `vite dev` |
| `codelist` | GraphQL 4005, gRPC 50005 | `npm run dev` in `services/codelist` |

The main checkout uses slot 0 and the base ports. A worktree gets slot 1-9 and
adds `slot × 100` to every port. The environment comes from the service's
`environment:` list in the checkout's `docker-compose.yml`, with hosts, ports
and database names replaced by this checkout's values. Logs, pid files and
the slot live in `~/work/.dev-stacks/<checkout-id>/`.

### Databases and test data

Each checkout owns `registries_<id>`, `registries_test_<id>` and, when codelist
runs, `codelist_<id>`, where `<id>` is the checkout ID with `-` replaced by `_`.

A new checkout's database is copied from a template. The template's name holds
a hash of `services/registries/prisma/migrations`:

1. `registries_seed_<hash>` holds the migrations plus the Analysis test
   registry. A copy takes about a second.
2. Without it, `registries_tpl_<hash>` holds the migrations only. The first
   checkout with that hash builds it, seeds its own copy through
   `~/work/scripts/create-registry.ts`, then saves the result as
   `registries_seed_<hash>` for the next checkout.

`dev stack up` writes `services/registries/.env.test.local`, so `npm run test`
in `services/registries` uses `registries_test_<id>`.

### Dependencies

`dev stack up` compares each service's `node_modules/.package-lock.json` with
its `package-lock.json` and installs only when they differ. Installs are
cached in `~/work/.dev-stacks/.shared/node_modules`, keyed by the lockfile
hash, and copied with an APFS directory clone, which takes about a second:

| The checkout has | `dev stack up` does |
|------------------|---------------------|
| `node_modules` matching the lockfile | nothing |
| no `node_modules`, and a cache entry for the lockfile | clones the cache entry |
| no `node_modules`, and no cache entry for the lockfile | clones the newest cache entry, then `npm install` adds the packages that differ |
| `node_modules` for another lockfile | `npm install` adds the packages that differ |

`npm ci` runs only when that `npm install` fails or leaves the tree different
from the lockfile. `dev stack up` restores `package-lock.json` if `npm install`
rewrote it. Each service runs `npm run generate` itself when it starts.

### Automatic cleanup

The launch agent `com.philip.dev-stack-reap` runs `dev stack reap` every 15
minutes and logs to `~/work/.dev-stacks/.shared/reap.log`. It:

- stops a stack that has had no open connection on its frontend or GraphQL
  port for two hours (`DEV_STACK_IDLE_SECONDS` overrides the limit);
- removes the stack state and databases of checkouts that no longer exist;
- drops template databases that no checkout's migrations use;
- removes cached `node_modules` that no checkout's lockfile uses, keeping the
  newest per workspace.

`dev stack reap --dry-run` prints what it would do.

### Patient services

`patient-bff` and `patient-frontend` do not run natively yet, so
`dev stack up --include-patient` fails. The Docker setup for them, including
the Helsenorge test notes, is in the history of `dev/stack.sh` and this README
before the native stack.

## Installation and compatibility

Both profiles link `~/bin/dev` to `dev/dev.sh`. Browser tooling is available on
personal machines too; the work profile installs Ledidi's stack dependencies.
Add new actions to the dispatcher and its help instead of creating another
top-level command. Scripts work in non-interactive shells for all three agents.

The terminal aliases `wt-up`, `wt-down`, `setup-stack`, `tunnel`, `sync-context`,
`sync-agent-configs`, and `browser` remain wrappers. Their help is safe too.
The old `dev start` alias now follows `dev stack up`, including readiness,
seeding and context updates; there is only one startup workflow.

Existing stack directories and saved slots retain their values.

Harness notification hooks remain separate: `claude-notify.sh`,
`codex-notify.sh`, and `cursor-notify.sh`. `mcp-datadog.sh` and `admin-mock/`
keep their integration-specific names. `python3 dev/claude-usage.py --help`
describes the Claude-only usage viewer.
