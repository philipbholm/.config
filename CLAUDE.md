# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Personal dotfiles/config directory for a macOS development environment. Version-controlled configs for shell, editor, terminal, window manager, coding agents (Claude Code, Codex CLI, Cursor agent CLI), and development workflow scripts targeting a Docker-based monorepo (Ledidi medical platform).

## Repository Structure

- `zsh/.zshrc` — Zsh config (symlinked to `~/.zshrc`). Key custom functions: `gwc` (create worktree + tmux + Cursor), `gwd` (delete worktree + nuke), `notify` (run command with macOS notification on finish), `tdl`/`tdlm`/`tsl` (tmux IDE layouts), `eff` (fuzzy open file). Aliases: `n` (nvim), `g` (git), `d` (docker), `t` (tmux attach/create), `ff` (fuzzy find with preview). Tool inits for eza, zoxide, fzf, starship, mise.
- `claude/` — Claude Code config: settings (model, permissions, plugins, hook declarations), custom agents, custom skills, `statusline-command.sh`, and `bin/` helpers. Both agents and skills are split by profile: `claude/skills/` holds the profile-agnostic skills (`explain-diff-html`) and `claude/skills.work/` the Ledidi-specific ones (create-issue, plan, implement, code-review, fix-feedback, learn); `claude/agents/` is the profile-agnostic agent dir (currently empty) and `claude/agents.work/` holds the Ledidi reviewers (ledidi-code-reviewer, ledidi-security-auth-reviewer, ledidi-test-reviewer). Hook *scripts* live in `dev/` (see `dev/claude-notify.sh`).
- `codex/` — Codex CLI config: `config.toml` (model, trusted projects, MCP servers, enabled plugins) symlinked to `~/.codex/config.toml`, `rules/default.rules` and `skills/code-review` symlinked into `~/.codex/`
- `dev/` — Development helper scripts symlinked to `~/bin/`. Core scripts:
  - `dev.sh` — Dev stack manager (auto-detects main vs worktree, wraps docker compose with correct override files)
  - `check.sh` — Lint + build verification for changed files
  - `test.sh` — Run tests for changed services with `--changed` flag support
  - `tunnel.sh` — Cloudflared tunnels for frontend + API
  - `db.sh` / `shell.sh` — Interactive database/container shells
  - `setup-worktree.sh` — Prepare worktree for IDE (npm ci, type generation)
  - `mcp-datadog.sh` — Datadog MCP launcher shared by all three agents; maps `DD_API_KEY`/`DD_APP_KEY` → `DATADOG_*` so no secret lands in a tracked config
  - `claude-notify.sh` — Telegram notify hook for Claude Code (Stop + Notification events) plus an on/off switch. Wired via the `hooks` block in `claude/settings.json`. Toggle with `claude-notify on|off|toggle|status`; state in machine-local `~/.claude/telegram-notify.state` (missing = enabled). Filters subagent stops; no-ops when `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID` are absent. `codex-notify.sh` is the Codex equivalent (currently disabled via `notify = []` in `config.toml`).
- `dev/claude/` — Per-repo and per-service CLAUDE.local.md files copied into worktrees
- `dev/feedback/` — PR review learnings extracted by `/learn` skill (mine/ and other/)
- `aerospace/aerospace.toml` — AeroSpace tiling WM (alt-based keybinds, vim-style navigation)
- `alacritty/` — Terminal config (JetBrainsMono Nerd Font, light/dark themes via symlink, Left Option as Alt for tmux)
- `tmux/tmux.conf` — Omarchy-style config. Prefix: Ctrl-Space (+ Ctrl-B secondary). Pane nav: prefix+hjkl and Ctrl+Alt+Arrows. Resize: prefix+HJKL and Ctrl+Alt+Shift+Arrows. Window nav: Alt+1-9, Alt+Left/Right. Session nav: Alt+Up/Down. Splits: prefix+s/v. Vi copy mode. Seamless Ctrl+hjkl navigation between nvim splits and tmux panes via vim-tmux-navigator. Blue status bar with PREFIX/ZOOM indicators.
- `git/config` — SSH commit signing, separate work identity via includeIf for `~/work/`. `git/allowed_signers` lists the keys trusted for local signature verification (add the work key line on work machines).
- `gh/config.yml` — GitHub CLI settings (`co` alias for `pr checkout`). `gh/hosts.yml` is machine-local auth state and gitignored.
- `cursor/` — Cursor **editor** (GUI) settings (`settings.json`, `keybindings.json`), symlinked from `~/Library/Application Support/Cursor/User/`
- `cursor-agent/` — Cursor **agent CLI** config (distinct from the GUI): `mcp.json` and `statusline.sh` symlinked into `~/.cursor/`; `cli-config.json` is a sanitized copy (auth stripped, not symlinked — Cursor rewrites secrets into the live file). See `cursor-agent/README.md` for restore steps. superpowers installs via `/add-plugin superpowers` in a Cursor chat (no CLI equivalent).
- `karabiner/` — Caps Lock → Esc (tap) / Ctrl (hold); Cmd+Tab → Ctrl+Tab in Cursor
- `borders/bordersrc` — JankyBorders window highlight (auto light/dark)
- `nvim/` — LazyVim config (Space leader, Tokyo Night theme, vim-tmux-navigator). Custom options in `lua/config/options.lua`, plugins in `lua/plugins/`
- `install.sh` / `install-common.sh` / `install-work.sh` / `install-personal.sh` — Profile-based bootstrap. `./install.sh work|personal` dispatches to the matching entry script; both source `install-common.sh` (brew, core dirs, Node LTS via nvm, symlinks, launch agents, theme, cleanup, LazyVim bootstrap, verification) then layer profile-specific packages and links, calling `setup_macos_defaults` (Dock autohide + pinned apps, battery percentage, fast key repeat, Finder hidden files/extensions) after their own Brewfile bundle. Idempotent.
- `Brewfile` / `Brewfile.work` / `Brewfile.personal` — Core packages plus per-profile package sets. Work adds Ledidi/dev tooling (cloudflared, watchman, lefthook, opentofu, aws-vpn-client, Chrome, ngrok, Slack); personal adds ansible, hcloud, helm, k3d, opentofu, Brave + Tailscale.
- `switch-theme.sh` — Toggle alacritty theme + borders based on macOS appearance
- `GUIDE.md` — Quick-reference for tools, tmux/nvim shortcuts, shell aliases, layout functions

## Key Patterns

**Worktree workflow**: Features are developed in git worktrees at `~/work/worktrees/{branch}`. Each gets an isolated Docker stack with port offsets. `gwc` creates everything (worktree + tmux + Cursor + setup), `gwd` tears it down.

**Claude Code skill lifecycle** (work profile only): `/create-issue` → `/plan` → `/implement` → `/review`. Issues and plans are stored in `~/vaults/work/dev/{repo}/issues/{NNN}-{branch}/`. The plan skill is read-only (exploration only), implement executes plans with quality gates and atomic commits.

**Notification hook**: `dev/claude-notify.sh` handles Claude Code's Stop + Notification events (Telegram), wired via the `hooks` block in `claude/settings.json`. The zsh `notify()` helper sends macOS desktop notifications and prefers `alerter`, falling back to `terminal-notifier` (in the Brewfile — `alerter` is no longer distributed via Homebrew) and then `osascript`.

**Script access**: Dev scripts are invoked via symlinks in `~/bin/` (e.g., `dev`, `check`, `tests`) and have zsh tab completions defined in `.zshrc`.

**Multi-agent parity**: Claude Code, Codex, and Cursor agent CLI are kept roughly in sync. All three share the `chrome-devtools` + `datadog` MCP servers (datadog via `dev/mcp-datadog.sh`) and the superpowers skill set. Plugins/superpowers are installed through each tool's own plugin manager (Claude: `enabledPlugins` in `settings.json`; Codex: `codex plugin add` → `[plugins.*]` in `config.toml`; Cursor: `/add-plugin` in-chat). The plugin payloads live in each tool's cache and are NOT version-controlled — only the enablement/config is. Codex/Cursor cannot replicate Claude's full custom skill set (create-issue/plan/implement/learn/fix-feedback); those remain Claude-only.

**Work agent config**: The base `claude/settings.json`, `codex/config.toml`, and `cursor-agent/mcp.json` hold only shared content. Work-only bits (Datadog MCP, Codex `~/work` project-trusts) live in `*.work.*` overlay files and are merged into real (non-symlink) live files on work machines by `dev/sync-agent-configs.sh` (run by `install-work.sh`; re-run after editing a base/overlay on a work machine). On personal machines the base files stay symlinked. Same idea for SSH: `ssh/config` is the personal base (github.com → `~/.ssh/github`) linked by `install-common.sh`; `ssh/config.work` (github.com → `~/.ssh/github_work`, plus bitbucket) replaces the symlink in `install-work.sh`. Claude skills and agents follow the same split, but via per-entry symlinks rather than an overlay merge: `link_claude_dir` in `install-common.sh` populates `~/.claude/skills` and `~/.claude/agents` from `claude/skills/` and `claude/agents/`, and `install-work.sh` re-runs it with the matching `.work` dirs added. It prunes its own previous links first, so a personal reinstall on a former work machine drops the work skills and agents while leaving any machine-local ones alone. Work shell functions (`gwc`/`gwd`/`dev`/`check`/`fix`/`prisma`/`sync-context`) live in `zsh/.zshrc.work`, sourced by `.zshrc` only when `~/work` exists.

## When Editing These Configs

- Shell functions/aliases go in `zsh/.zshrc`. Secrets load from `zsh/.zsh_secrets` (gitignored).
- Claude skills go in `claude/skills/` (both profiles) or `claude/skills.work/` (work only); agents likewise in `claude/agents/` or `claude/agents.work/`. Settings in `claude/settings.json`. After adding or removing a skill or agent, re-run the installer for the profile — `~/.claude/skills` and `~/.claude/agents` are real directories of per-entry symlinks, not links to the repo.
- Dev scripts use Bash (except `check.sh` and `test.sh` which use Zsh). Scripts must be executable.
- The `.gitignore` excludes: cagent, configstore, kanata, neofetch, rstudio, raycast, tmp, .zsh_secrets, .zcompdump.

## Shorthand Phrases

- **"update the context"** — Update `CLAUDE.local.md` and `AGENTS.md` under `dev/context/ledidi-monorepo/` (relative to this repo root), plus any files they reference.
