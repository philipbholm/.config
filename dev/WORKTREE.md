# Worktree & Dev Scripts

This document explains the three scripts used to run isolated app stacks from the main repo and git worktrees.

## Overview

| Script | Purpose |
|--------|---------|
| `run-main.sh` | Run the app stack from the main repo (default ports) |
| `run-worktree.sh` | Run an isolated app stack from a git worktree (offset ports) |
| `setup-worktree.sh` | Install dependencies and generate types on the host for IDE support |

All stacks run the same set of services:
`main-frontend`, `router`, `router-autoupdate`, `postgres`, `mysql`, `admin`, `codelist`, `registries`

Auth services (SpiceDB, auth-service) are excluded. The admin service's dependency on auth-service is overridden.

## Shared Docker Images

To avoid rebuilding the same images per stack, `router-autoupdate`, `admin`, and `codelist` use shared image tags (`ledidi-shared-*`). The first stack to start builds these images; subsequent stacks reuse them. `main-frontend` and `registries` are built per-project since their code differs across branches.

## run-main.sh

Runs the app stack from the main repo using default ports. Generates a `docker-compose.dev.yml` override file in `/Users/philip/work/tmp/dev-stacks/ledidi-monorepo/` that sets shared image names and removes the auth-service dependency from admin.

```bash
scripts/run-main.sh --up          # Create and start the stack
scripts/run-main.sh --up --rebuild  # Rebuild images before starting
scripts/run-main.sh --stop        # Stop containers (keep them)
scripts/run-main.sh --start       # Restart stopped containers
scripts/run-main.sh --down        # Stop and remove containers/networks
scripts/run-main.sh --nuke        # Remove containers, volumes, and images
```

On `--up`, the script seeds the MySQL database (admin schema + test datasources) and PostgreSQL (ATC codes).

The app runs at http://localhost:3001/en.

## run-worktree.sh

Runs an isolated app stack from a git worktree. Each worktree is assigned a **slot** (1-9) that determines a port offset (`slot * 100`). For example, slot 1 maps the frontend to port 3101, slot 2 to port 3201, etc.

```bash
scripts/run-worktree.sh --up              # Auto-assign next available slot
scripts/run-worktree.sh --up --slot=2     # Use a specific slot
scripts/run-worktree.sh --up --rebuild    # Rebuild images before starting
scripts/run-worktree.sh --stop            # Stop containers (keep them)
scripts/run-worktree.sh --start           # Restart stopped containers
scripts/run-worktree.sh --down            # Stop and remove containers/networks
scripts/run-worktree.sh --nuke            # Remove containers, volumes, and images
scripts/run-worktree.sh --status          # List all running worktree stacks
```

### Slot management

- Slot 0 is reserved for the main repo (`run-main.sh`).
- On `--up`, the script auto-assigns the lowest available slot (1-9) and saves it to `/Users/philip/work/tmp/dev-stacks/<worktree-name>/worktree-slot`.
- Subsequent commands (`--stop`, `--down`, etc.) read the saved slot automatically.
- `--nuke` clears the saved slot and removes the tmp directory.
- Running worktree stacks are discovered via a Docker label (`com.ledidi.worktree-slot`) on the `main-frontend` container.

### Port mapping (slot N)

| Service | Port |
|---------|------|
| Frontend | `3001 + N*100` |
| Router (GraphQL) | `4000 + N*100` |
| PostgreSQL | `5432 + N*100` |
| MySQL | `3336 + N*100` |
| Admin (GraphQL) | `4004 + N*100` |
| Admin (gRPC) | `50004 + N*100` |
| Codelist (gRPC) | `50005 + N*100` |
| Registries (GraphQL) | `4006 + N*100` |
| Registries (gRPC) | `50006 + N*100` |

### Isolation

- **Ports**: Offset by slot number, no conflicts between stacks.
- **Docker project name**: Set to the worktree folder name (e.g., `sidebar`, `my-feature`).
- **Network**: Each worktree gets its own Docker network (`default-network-wt-N`).
- **Databases**: Each worktree has its own PostgreSQL and MySQL volumes.
- **Router CORS**: A worktree-specific `router.docker.worktree.yaml` is generated in the tmp directory with the correct frontend origin.

### Generated files

All generated/temporary files are stored outside the repo in `/Users/philip/work/tmp/dev-stacks/<worktree-name>/` to avoid gitignore issues:

- `docker-compose.worktree.yml` — compose override with port offsets
- `router.docker.worktree.yaml` — router config with correct CORS origin
- `worktree-slot` — saved slot number

For the main repo, files are stored in `/Users/philip/work/tmp/dev-stacks/ledidi-monorepo/`.

### CLAUDE.local.md

On `--up`, the script writes a port table into `CLAUDE.local.md` so Claude Code knows which ports to use. On `--down` and `--nuke`, the block is removed. The file is gitignored.

## setup-worktree.sh

Prepares the host filesystem for development in a worktree. This is **not required** for running the app (Docker handles builds inside containers), but is needed for:

- IDE autocompletion and TypeScript type checking
- Running tests locally (outside Docker)
- Linting locally

```bash
scripts/setup-worktree.sh              # Set up current directory
scripts/setup-worktree.sh /path/to/wt  # Set up a specific worktree
```

Steps performed:
1. `npm install` in all packages, services, and apps
2. `npm run build` in shared packages (logger, authentication, expression, eslint)
3. `npm run generate` in all services and apps (GraphQL, Prisma, gRPC types)
4. Creates `supergraph.graphql` placeholder if missing

## Typical workflow

```bash
# 1. Create a worktree
git worktree add ../my-feature feature-branch

# 2. (Optional) Set up host for IDE support
scripts/setup-worktree.sh ../my-feature

# 3. Start the isolated stack
cd ../my-feature
scripts/run-worktree.sh --up

# 4. Develop, test, etc.
# App is at http://localhost:3101/en (slot 1)

# 5. Stop when done
scripts/run-worktree.sh --down

# 6. Clean up everything
scripts/run-worktree.sh --nuke
```
