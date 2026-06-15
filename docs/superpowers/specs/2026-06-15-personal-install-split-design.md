# Personal/Work Install Split — Design

**Date:** 2026-06-15
**Status:** Draft for review

## Problem

`install.sh` is a single monolithic bootstrap that installs everything — including
work-specific tooling (Ledidi dev scripts, work git identity, AWS VPN, Datadog MCP,
Slack, Chrome). There's no way to bring up a clean *personal* machine without the
work cruft. We want **two first-class install profiles** — `work` and `personal` —
that share a common core.

## Goals

- Two equal profiles selected by **separate entry scripts**, sharing one common library.
- Personal machine carries **zero** work-only content (full extraction, not inert leftovers).
- Keep the version-controlled-config + symlink-to-repo workflow wherever possible.

## Non-goals / out of scope (follow-ups)

- Splitting `claude/skills` and `claude/agents` into shared vs work-specific. (Your
  "Ledidi agent context" scope was `dev/context`, `dev/feedback`, `dev/claude` + the
  Datadog MCP wiring — not the skills/agents dirs. Treated as shared for now.)
- Reclassifying `docker-desktop` / `lazydocker` / `tailscale-app` as work-only — kept
  core unless you decide otherwise.

## Selected decisions

| Decision | Choice |
|---|---|
| Profile relationship | Two distinct profiles sharing a common core |
| Selection mechanism | Separate entry scripts (`install-work.sh`, `install-personal.sh`) |
| Work-only categories | Dev scripts + `~/work` dirs; work git identity; work apps/tooling; Ledidi agent context; Chrome |
| Extraction depth | Full extraction — no inert work bits left in shared files |
| Agent MCP mechanism | Generate merged live files (jq for JSON, concat for TOML) |
| `cursor/` folder | Keep as-is for now |
| `nvm` | **Kept** (manages Node); no standalone `node` package existed |
| `brave-browser` | **Personal-only** |
| `tailscale-app` | **Personal-only** |
| `docker-desktop` / `lazydocker` | Core |
| `google-chrome` | Work-only |

## Repo structure

```
install.sh             # thin dispatcher: ./install.sh work|personal (errors if arg omitted)
install-common.sh      # sourced library of core install functions
install-work.sh        # source common → run core → layer work-only
install-personal.sh    # source common → run core → layer personal-only
Brewfile               # core packages
Brewfile.work          # work-only packages
Brewfile.personal      # personal-only packages
```

`install-common.sh` exposes functions (`preflight`, `install_homebrew`,
`brew_bundle <file>`, `link_core`, `setup_launch_agents`, `setup_theme`,
`cleanup_stale`, `verify`). Entry scripts call the core sequence, then add their layer.
The dispatcher `install.sh` validates the arg and `exec`s the matching entry script.

## 1. Package classification

**Core** (`Brewfile`): gh, mas, neovim, **nvm**, tmux, uv, dark-notify, borders, bat,
btop, eza, fd, fzf, lazydocker, lazygit, mise, ripgrep, starship, zoxide; casks
alacritty, bitwarden, chai, codex, **cursor-cli**, docker-desktop,
font-jetbrains-mono-nerd-font, kap, karabiner-elements, logi-options+, lunar,
aerospace, obsidian, raycast, spotify, ticktick. Taps: cormacrelf, felixkratz,
nikitabobko.

**Work** (`Brewfile.work`): brews cloudflared, watchman, lefthook, opentofu; casks
aws-vpn-client, **google-chrome**, ngrok, slack.

**Personal** (`Brewfile.personal`): casks **brave-browser**, **tailscale-app**.

> Already applied to the live `Brewfile`: `cursor` → `cursor-cli` (`nvm` retained). The
> brave/chrome/work-package moves happen when the Brewfiles are split.

## 2. Symlinks & directories

**`install-common.sh` (core, both profiles):**
- `~/.zshrc`, `~/.ssh/config`
- Cursor GUI settings (`cursor/settings.json`, `cursor/keybindings.json` → `~/.cursor/`)
- Claude / Codex / Cursor-agent **base** configs (clean, no work bits) — symlinked
- Cursor-agent `statusline.sh`
- Core dirs: `~/bin`, `~/.claude`, `~/.codex/{rules,skills}`, `~/.cursor`, `~/vaults`,
  `~/private`, `~/.ssh`, `~/.zsh`, `~/.nvm`
- `python`/`pip` → python3/pip3 shims
- Theme launchd agents, `switch-theme.sh`, zsh-autosuggestions, nvim cleanup, verification

**`install-work.sh` (after core):**
- Dev-script symlinks → `~/bin`: `dev`, `check`, `tests`, `tunnel`, `gwc`, `gwd`,
  `sync-context`, `fix`
- `~/work`, `~/work/worktrees`, `~/work/.dev-stacks` dirs
- `brew bundle Brewfile.work`
- `zsh/.zshrc.work` symlink (work shell functions — §4)
- Work agent config generation (§4)

**`install-personal.sh` (after core):**
- `brew bundle Brewfile.personal`
- (placeholder for future personal-only symlinks)
- No `~/work`, no dev scripts, no work agent config

## 3. Git config

No change. `git/config` uses directory-gated `includeIf`:
`~/work/` → `git/work/config`, `~/private/` → `git/private/config`. On a personal
machine `~/work` never exists, so the work identity never activates. Self-extracting.

## 4. Full extraction of embedded work bits

### 4a. Shell functions → `zsh/.zshrc.work`

Move `gwc`, `gwd` (+ completions), `sync-context`, and the dev-stack helper functions
out of `zsh/.zshrc` into a new `zsh/.zshrc.work`. Because both profiles share the same
repo checkout, the file exists on disk regardless of profile — so we gate sourcing on
the **`~/work` directory** (the same marker the git `includeIf` uses), which only
`install-work.sh` creates. At the end of `.zshrc`:

```zsh
[ -d "$HOME/work" ] && [ -f "$HOME/.config/zsh/.zshrc.work" ] && \
  source "$HOME/.config/zsh/.zshrc.work"
```

The NVM block (`.zshrc` 54-58) **stays** — `nvm` is retained.

### 4b. Agent configs — base + work overlay, generated on work

Base repo files hold **shared content only**:
- `claude/settings.json` — remove the `datadog` entry from `mcpServers` (keep chrome-devtools)
- `codex/config.toml` — remove `[mcp_servers.datadog]` and the three work
  `[projects."~/work/..."]` trust tables (keep `~/.config` trust + chrome-devtools)
- `cursor-agent/mcp.json` — remove the `datadog` entry (keep chrome-devtools)

New work-overlay fragment files:
- `claude/settings.work.json` → `{ "mcpServers": { "datadog": { "command": ".../dev/mcp-datadog.sh" } } }`
- `codex/config.work.toml` → `[mcp_servers.datadog]` + the three `[projects."~/work/..."]` tables
- `cursor-agent/mcp.work.json` → `{ "mcpServers": { "datadog": { ... } } }`

**Personal:** `install-common.sh` symlinks the clean base files directly. Done.

**Work:** `install-work.sh` generates real merged files (must `rm -f` the symlink first
so we never write through into the repo):

```bash
# JSON: deep-merge base + overlay
rm -f ~/.claude/settings.json
jq -s '.[0] * .[1]' "$DOTFILES/claude/settings.json" "$DOTFILES/claude/settings.work.json" > ~/.claude/settings.json

rm -f ~/.cursor/mcp.json
jq -s '.[0] * .[1]' "$DOTFILES/cursor-agent/mcp.json" "$DOTFILES/cursor-agent/mcp.work.json" > ~/.cursor/mcp.json

# TOML: independent tables → safe to concatenate
rm -f ~/.codex/config.toml
cat "$DOTFILES/codex/config.toml" "$DOTFILES/codex/config.work.toml" > ~/.codex/config.toml
```

A helper `dev/sync-agent-configs.sh` (symlinked as `~/bin/sync-agent-configs`, work-only)
wraps these three commands so editing the repo base/overlay on a work machine is a
one-command re-sync. `install-work.sh` calls it.

> Trade-off accepted: on a **work** machine these three files are generated (not
> symlinks), so shared-content edits go through the repo source + `sync-agent-configs`.
> On personal they remain live symlinks.

## 5. Cursor / Node status

- `cursor` GUI cask → `cursor-cli` (done in `Brewfile`).
- `cursor/` GUI-settings folder + its symlinks: kept as-is (core).
- `nvm` retained; `~/.nvm` dir, the `.zshrc` NVM block, and the "Install Node" manual
  step all stay. No node cleanup.

## 6. Idempotency & re-runs

- All symlinks use `ln -sf` / `ln -sfn` (already the pattern).
- Generated agent files: `rm -f` then write — safe to re-run.
- `brew bundle` is idempotent.
- Re-running an entry script reconverges its profile.

## 7. Manual follow-up (per profile)

The closing "manual follow-up" list is split: shared steps (SSH keys, `.zsh_secrets`,
`gh auth`, Docker, background services, nvim bootstrap, reload shell) in common;
work-only steps (Node default via nvm, work sign-ins) shown by `install-work.sh` only.

## Open questions for reviewer

1. ~~`docker-desktop` / `lazydocker` / `tailscale-app`~~ — resolved: docker + lazydocker
   stay core; tailscale-app is personal-only.
2. Confirm gating `.zshrc.work` on `~/work` existence is acceptable (vs an explicit marker file).
