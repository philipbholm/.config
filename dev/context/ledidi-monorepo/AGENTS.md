# AGENTS.md

Guidance for agents working in the Ledidi monorepo.

## Project Overview

Medical registry platform. Each service/app has its own `package.json`.

| Path | Description |
|------|-------------|
| `apps/registries-frontend/` | Registries frontend (React 19 + Vite) |
| `services/registries/` | Registries backend (PostgreSQL, GraphQL + gRPC) |
| `services/codelist/` | Code list service (PostgreSQL, gRPC only) |
| `packages/` | Shared libraries (@ledidi-as scope) |

Default focus is `services/registries` and `apps/registries-frontend` unless I
say otherwise. The sibling apps — `analysis-room-frontend`, `legacy-frontend`,
`patient-frontend`, `shell` — are in scope only when I name one.

### Terminology

- **Trials** and **studies** are the same thing in this repo, interchangeable.
  Studies use the shell app as their frontend.
- **John** is the AI agent that analyses tenders for Ledidi.

## Ports (Worktree-Specific)

This is one of many parallel worktrees, each with its own isolated Docker stack
and unique ports.

| Service | URL |
|---------|-----|
| Frontend | http://localhost:{{FRONTEND_PORT}}/en/registries |
| Registries (GraphQL) | http://localhost:{{REGISTRIES_PORT}}/graphql |
| Registries (gRPC) | localhost:{{REGISTRIES_GRPC_PORT}} |
| Codelist (gRPC) | localhost:{{CODELIST_GRPC_PORT}} |
| PostgreSQL | localhost:{{POSTGRES_PORT}} |

These ports belong to this worktree alone, and they are correct as listed. When
one doesn't respond, the Docker stack is what needs attention — the standard
ports (5432, 3000, 4000) belong to other stacks, and editing hardcoded URLs, env
files, or configs to reach a service breaks the worktree instead of fixing it.

## Workflow

### Creating a PR

"Create a PR that <does something>" runs every step below; a bare "create pr"
runs the ones whose precondition still holds. A preceding `/grilling` or
`/to-spec` does not consume the instruction — interview in the main checkout,
and start step 1 when I confirm. That confirmation is the only approval the
design needs.

1. **Spec.** Larger efforts get a spec at `.scratch/<slug>/spec.md` before
   implementation; judge the size yourself. A smaller change gets no spec file:
   its design, and the alternative you discarded, go in the PR's `## Why`.
   Effort files always live in the main checkout's `.scratch/`, reached by
   absolute path — a worktree has none of its own.

2. **Worktree.** Uncommitted changes where you are standing mean stop and ask;
   they may be the work I mean. A feature branch with commits in the main
   checkout comes along as-is: `wt-up <name> <branch>`. Anything else starts
   fresh: `git fetch origin`, then branch from `origin/master`, because `wt-up`
   fetches nothing and an inherited HEAD is whatever was checked out last. One
   kebab-case string names both worktree and branch — report it in your first
   update, and stop and ask when a directory of that name already exists.

3. **Dependencies.** Run `setup-stack`, naming any extra workspace the branch
   touches.

4. **Containers.** Start `dev up postgres -d`. Browser work needs `dev up`, and
   `dev status` before it: I can run three stacks at once, so ask before
   starting a fourth.

5. **Implement**, running the suites for the workspaces you touched — see
   **Starting containers**. E2E when I ask for it.

6. **Review.** Run `/code-review` and fix what it finds. The PR does not exist
   yet, so those fixes land as ordinary commits.

7. **Open it.** `gh pr create --draft`, gitmoji title, `risk:standard` label,
   `## Why` and `## What` sections, then open its URL in my browser. A
   product-code PR updates the story-map data under
   `services/registries/docs/story-map/src/data/` when user-visible behavior
   changes; otherwise tick the **Story map reviewed** checkbox added by the bot.

8. **Checks.** Run `gh pr checks <number>`. A red `pr-checks` blocks master —
   fix it and push. Report every other failing check.

9. **Report.** The worktree path, the branch, the containers you started and
   their ports, which suites ran and which the stack could not support, the
   review's outcome, the PR URL, and the state of its checks.

A step that fails ends the flow there. Name the step, say what state the
worktree is in, and leave it standing — `setup-stack`'s npm install is the
expensive part, and it survives a fixed `GITHUB_TOKEN`.

### Worktrees

Worktrees live at `<repo>/.worktrees/<name>` — nowhere else. The path is shared
by every agent harness.

- **New branch** → `wt-up <name> <branch> [start-point]`.
- **Existing branch** → `wt-up <name> <branch>`.
- Name the branch in kebab-case, short, and with no prefix.
  `numeric-summary-family`, not `feat/numeric-summary-family` and not
  `worktree-numeric-summary-family`.
- Continue the task from the path printed by `wt-up`, then run `setup-stack`.
- Always choose an explicit name. The directory name becomes the Docker stack
  ID, so generated names produce unpredictable compose project names and
  orphaned slot files.
- `setup-stack` installs dependencies and generates types. It starts no
  containers.

### Starting containers

The Docker stack is opt-in, and different work needs different amounts of it.
Start the row that matches the task:

| Task | Command |
|------|---------|
| tsc, biome, frontend unit tests | nothing — `setup-stack` covers it |
| Backend suite (`services/registries`) | `dev up postgres -d` |
| Playwright E2E, browser verification | `dev up` |

Postgres alone carries the backend suite: the vitest global setup
(`src/test-setup.ts`) runs `generate` and `migrate-reset --force` against
`POSTGRES_URL`, building `registries-test` itself. Starting postgres alone also
skips the admin-mock container that `registries` requires.

`dev up` fills in the port table above — there is no separate `sync-context` to
run. It also writes `services/registries/.env.test.local` pointing at the test
database, but only when `registries` is one of the services it started. So after
a full `dev up` the backend suite runs on a bare `npm run test`; after
`dev up postgres` pass `POSTGRES_URL` on the command line. The port comes from
the table, never from an edited config file.

Run each suite directly — no wrapper decides for you. The container table above
says which ones the current stack supports: frontend unit tests need nothing, the
registries suite needs postgres, e2e needs everything. Vitest's
`--changed origin/master` narrows a run to the tests your change reaches through
the import graph, and both `services/registries` and `apps/registries-frontend`
accept it; `services/codelist` is on Jest and has no equivalent.

Nothing flags a suite you never started, so a green frontend run is not a green
branch. Say which suites ran and which the current stack couldn't support.

### Tearing down

**Not until the PR is merged.** The stack stays up for the whole life of the
branch. A green suite is not a reason to stop it, and neither is the end of a
session. Never run `dev down`, `dev nuke`, or `wt-down` on your own initiative.

`dev restart <service>` and `dev up --build <service>` are not teardown — use
them freely while working.

When you finish with containers still running, name the stack and its ports so
nothing is left running silently.

After the merge, teardown is `wt-down` from inside the worktree. Not
`ExitWorktree action:remove`, which deletes the branch and leaves the Docker
stack orphaned.

### Environment

- **Use `dev` instead of `docker compose`** — includes correct compose files
- With the stack up, backend `.ts` changes auto-reload (nodemon) and the
  frontend uses Vite HMR
- Generated code never reloads. Run the matching workflow below.
- Never run `npm run dev` / `npm start` — services run in Docker

| Change | Workflow |
|------|---------|
| Backend `.graphql` schema | `services/registries: npm run generate` → `services/apollo-router: ./compose-supergraph.sh` → `apps/registries-frontend: npm run generate` → restart registries, frontend, and router |
| `.proto` | Run `npm run generate-proto` in the owner, generate in every consumer, then restart affected services |
| `prisma/schema.prisma` | Create and inspect the migration, apply it, run `npm run generate`, then restart the service; pass this worktree's `POSTGRES_URL` to every database command |
| `package.json` | Run `npm install`, then `dev up --build <service> -d`; a restart does not install dependencies |

When upgrading a service Docker image for a vulnerability, check whether its
migrator uses the same image and needs the same upgrade.

### Commands

**Always use package.json scripts.** Never run tools directly:

```bash
# Correct
npm run generate
npm run migrate
npm run test

# Wrong
npx prisma generate
npx prisma migrate dev
npx jest
```

### User Instructions

| When user says | What it means |
|----------------|---------------|
| "verify in browser" | Start the full stack if it isn't up, then open the browser and verify yourself |
| "red/green TDD" | Run both unit tests and relevant E2E tests |
| "commit" | Pre-commit hook must pass |
| "push" | Pre-push hook must pass |
| "create pr" / "open pr" | Run the **Creating a PR** flow |
| "save to vault" | Write a markdown file to `/Users/philip/vaults/work/dev` |

Committing and pushing don't need approval. Labels beyond `risk:standard` do.

### Failing Builds and Tests

Fix pre-existing lint or type errors first and commit that fix before starting
new work.

While master is green, a failing build, tool, or test comes from this branch.
Those are yours to fix and stay on, including the ones that look unrelated to
what you changed.

### Troubleshooting Dev Environment

Start with the container logs — they describe what actually happened, where
anything earlier is a guess.

1. `docker ps` to list running containers
2. Find the ones carrying this worktree's name (e.g. `worktree-name-registries-1`)
3. Read their logs, then restart or adjust those containers as needed

Only containers with the worktree name belong to this environment. A connection
failure means container state, not port configuration.

After opening a branch in a worktree, load the frontend URL and confirm the page
renders. **"An unknown error occurred. Please try again later or contact
support."** is a Docker-side problem, not an application bug — usually a service
needing a restart, an unrun migration, or missing dependencies.

### Datadog

Open a Datadog link and confirm it returns results before putting it in a
comment, PR, or report. These URLs are easy to construct plausibly and wrong; a
link showing nothing costs more than no link.

## Coding Standards

Read
[CODING_STANDARDS.md](/Users/philip/.config/dev/context/CODING_STANDARDS.md)
before changing or reviewing code. The file is the shared authority for
engineering, security, privacy, reliability, and testing rules. This repository
context adds operational detail but does not duplicate those rules.
