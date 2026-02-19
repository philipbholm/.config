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
| `sync-codex` | Sync Codex MCP servers from Claude config |
| `link-opencode-config` | Symlink OpenCode config paths to Claude-managed files |
| `sync-opencode` | Translate Claude settings/state to OpenCode config |

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
~/bin/sync-codex -> ~/.config/dev/sync-codex-from-claude.sh
~/bin/verify-codex-parity -> ~/.config/dev/verify-codex-parity.sh
~/bin/link-opencode-config -> ~/.config/dev/link-opencode-config.sh
~/bin/sync-opencode -> ~/.config/dev/sync-opencode-from-claude.sh
~/bin/verify-opencode-parity -> ~/.config/dev/verify-opencode-parity.sh
```

## Why Symlinks?

Symlinks in `~/bin` ensure commands work in all shell contexts, including:
- Interactive terminal sessions
- Non-interactive shells (e.g., Claude Code, scripts)
- IDE integrated terminals

## Codex Parity Workflow

- `~/.config/dev/link-claude-context.sh` links `CLAUDE.local.md` and `AGENTS.md` into a repo/worktree.
- `~/.config/dev/sync-codex-from-claude.sh` syncs Codex MCP servers from `~/.claude/.claude.json`.
- `~/.config/dev/link-opencode-config.sh` links OpenCode `AGENTS.md`/`skills` to Claude-managed files.
- `~/.config/dev/sync-opencode-from-claude.sh` generates `~/.config/opencode/opencode.json` from Claude settings/state.
- `~/.config/dev/verify-opencode-parity.sh` verifies symlink wiring and generated OpenCode parity config.
- `gwc` now links context files via symlink instead of copying templates.
