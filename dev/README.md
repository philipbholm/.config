# Dev Scripts

Development utility scripts for the monorepo.

## Available Commands

| Command | Description |
|---------|-------------|
| `dev` | Smart docker compose wrapper — auto-detects main vs worktree |
| `check` | Run linting, formatting, and build on changed files |
| `tests` | Run tests (unit, integration, e2e) on changed files |
| `tunnel` | Start cloudflared tunnels for remote access |

## `dev` — Unified Dev Stack Manager

`dev` wraps `docker compose` with automatic environment detection. It determines whether you're in the main checkout or a git worktree, generates the correct compose override file (port offsets, networking, volumes), and forwards your command to `docker compose`.

```bash
# These are equivalent:
dev restart registries
docker compose -f docker-compose.yml -f <override> restart registries
```

### Commands

| Command | Description |
|---------|-------------|
| `dev up` | Full init: generate override, start services, seed DB, sync `CLAUDE.local.md` and `AGENTS.md` |
| `dev up --build <service>` | Rebuild a specific service (replaces old `rebuild` command) |
| `dev down` | Stop and remove containers |
| `dev nuke` | Full teardown: containers, volumes, images, slot, tmp dir |
| `dev start [services...]` | Start stopped containers (reconnects admin-mock networking) |
| `dev status` | Show all running stacks (main + worktrees) |
| `dev <anything else>` | Pure passthrough to `docker compose` |

### Passthrough Examples

Any docker compose command works — `dev` just injects the right `-f` flags:

```bash
dev restart registries       # Restart a service
dev logs -f registries       # Tail logs
dev exec registries sh       # Shell into container
dev ps                       # List containers
dev build registries         # Build image without starting
dev stop                     # Stop without removing
```

### Mode Detection

`dev` auto-detects the environment by checking the `.git` entry at the repo root:

- **Main checkout** (`.git` is a directory) → slot 0, default ports, shared admin-mock networking
- **Worktree** (`.git` is a file) → slots 1–9, ports offset by `slot × 100`, isolated network

### Port Mapping (Worktrees)

Each worktree gets a unique slot (1–9). Ports are offset by `slot × 100`:

| Service | Main (slot 0) | Slot 1 | Slot 2 |
|---------|--------------|--------|--------|
| Frontend | 3003 | 3103 | 3203 |
| Router | 4000 | 4100 | 4200 |
| Postgres | 5432 | 5532 | 5632 |
| Codelist | 4005 | 4105 | 4205 |
| Registries | 4006 | 4106 | 4206 |

### Override Files

`dev` writes a generated compose override to:

```
~/work/.dev-stacks/<project-name>/docker-compose.stack.yml
```

This file is regenerated on every command. The `DEV_STACKS_DIR` env var controls the base directory.

## Setup

Scripts in this directory are made available as commands via symlinks in `~/bin`.

To add a new command:

```bash
ln -sf ~/.config/dev/<script>.sh ~/bin/<command>
```

For example:
```bash
ln -sf ~/.config/dev/check.sh ~/bin/check
```

## Current Symlinks

```bash
~/bin/dev     -> ~/.config/dev/dev.sh
~/bin/check   -> ~/.config/dev/check.sh
~/bin/tests   -> ~/.config/dev/test.sh
~/bin/tunnel  -> ~/.config/dev/tunnel.sh
```

## Why Symlinks?

Symlinks in `~/bin` ensure commands work in all shell contexts, including:
- Interactive terminal sessions
- Non-interactive shells (e.g., Claude Code, scripts)
- IDE integrated terminals
