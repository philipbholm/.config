# Dev Scripts

Development utility scripts for the monorepo.

## Available Commands

| Command | Description |
|---------|-------------|
| `check` | Run linting, formatting, and build on changed files |
| `tests` | Run tests (unit, integration, e2e) on changed files |
| `rebuild` | Rebuild Docker containers |
| `db` | Database utilities |
| `shell` | Open a shell in a Docker container |
| `tunnel` | Start cloudflared tunnels for remote access |

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
~/bin/check   -> ~/.config/dev/check.sh
~/bin/tests   -> ~/.config/dev/test.sh
~/bin/rebuild -> ~/.config/dev/rebuild.sh
~/bin/db      -> ~/.config/dev/db.sh
~/bin/shell   -> ~/.config/dev/shell.sh
~/bin/tunnel  -> ~/.config/dev/tunnel.sh
```

## Why Symlinks?

Symlinks in `~/bin` ensure commands work in all shell contexts, including:
- Interactive terminal sessions
- Non-interactive shells (e.g., Claude Code, scripts)
- IDE integrated terminals
