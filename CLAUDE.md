# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal dotfiles/config directory for a macOS development environment. Version-controlled configs for shell, editor, terminal, window manager, Claude Code, and development workflow scripts targeting a Docker-based monorepo (Ledidi medical platform).

## Repository Structure

- `zsh/.zshrc` — Zsh config (symlinked to `~/.zshrc`). Key custom functions: `gwc` (create worktree + tmux + Cursor), `gwd` (delete worktree + nuke), `notify` (run command with macOS notification on finish)
- `claude/` — Claude Code config: hooks (desktop notifications via alerter), settings (model, permissions, plugins), custom agents (auth-reviewer, security-reviewer), custom skills (create-issue, plan, implement, review, learn)
- `dev/` — Development helper scripts symlinked to `~/bin/`. Core scripts:
  - `dev.sh` — Dev stack manager (auto-detects main vs worktree, wraps docker compose with correct override files)
  - `check.sh` — Lint + build verification for changed files
  - `test.sh` — Run tests for changed services with `--changed` flag support
  - `tunnel.sh` — Cloudflared tunnels for frontend + API
  - `db.sh` / `shell.sh` — Interactive database/container shells
  - `setup-worktree.sh` — Prepare worktree for IDE (npm ci, type generation)
- `dev/claude/` — Per-repo and per-service CLAUDE.local.md files copied into worktrees
- `dev/feedback/` — PR review learnings extracted by `/learn` skill (mine/ and other/)
- `aerospace/aerospace.toml` — AeroSpace tiling WM (alt-based keybinds, vim-style navigation)
- `alacritty/` — Terminal config (JetBrainsMono Nerd Font, light/dark themes via symlink)
- `tmux/tmux.conf` — Prefix: Ctrl-Space, vim pane nav, mouse enabled
- `git/config` — SSH commit signing, separate work identity via includeIf for `~/work/`
- `cursor/` — Cursor editor settings (`settings.json`, `keybindings.json`), symlinked from `~/Library/Application Support/Cursor/User/`
- `karabiner/` — Caps Lock → Esc (tap) / Ctrl (hold); Cmd+Tab → Ctrl+Tab in Cursor
- `borders/bordersrc` — JankyBorders window highlight (auto light/dark)
- `nvim/init.lua` — Minimal neovim (relative lines, 2-space tabs, persistent undo)
- `switch-theme.sh` — Toggle alacritty theme + borders based on macOS appearance

## Key Patterns

**Worktree workflow**: Features are developed in git worktrees at `~/work/worktrees/{branch}`. Each gets an isolated Docker stack with port offsets. `gwc` creates everything (worktree + tmux + Cursor + setup), `gwd` tears it down.

**Claude Code skill lifecycle**: `/create-issue` → `/plan` → `/implement` → `/review`. Issues and plans are stored in `~/vaults/main/dev/{repo}/issues/{NNN}-{branch}/`. The plan skill is read-only (exploration only), implement executes plans with quality gates and atomic commits.

**Notification hook**: `claude/hooks/notification-desktop.sh` sends macOS desktop notifications (via alerter) when Claude needs attention. Includes aerospace workspace + tmux window index in title for context.

**Script access**: Dev scripts are invoked via symlinks in `~/bin/` (e.g., `dev`, `check`, `tests`) and have zsh tab completions defined in `.zshrc`.

## When Editing These Configs

- Shell functions/aliases go in `zsh/.zshrc`. Secrets load from `zsh/.zsh_secrets` (gitignored).
- Claude skills go in `claude/skills/`, agents in `claude/agents/`. Settings in `claude/settings.json`.
- Dev scripts use Bash (except `check.sh` and `test.sh` which use Zsh). Scripts must be executable.
- The `.gitignore` excludes: cagent, configstore, kanata, neofetch, rstudio, raycast, tmp, .zsh_secrets, .zcompdump.
