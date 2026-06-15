# Personal/Work Install Split — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the monolithic `install.sh` into two first-class install profiles — `work` and `personal` — sharing a common core, with all work-only content fully extracted from shared files.

**Architecture:** A thin `install.sh work|personal` dispatcher `exec`s `install-work.sh` or `install-personal.sh`, each of which sources a shared `install-common.sh` library and then layers its profile. The Brewfile is split into `Brewfile` (core) + `Brewfile.work` + `Brewfile.personal`. Work shell functions move to a `~/work`-gated `zsh/.zshrc.work`. Agent Datadog/Codex-trust config is stripped from the clean base files and re-merged into real files on work machines via `dev/sync-agent-configs.sh`.

**Tech Stack:** Bash/Zsh, Homebrew Bundle, `jq` (JSON merge), TOML concatenation, macOS `launchctl`.

**Spec:** `docs/superpowers/specs/2026-06-15-personal-install-split-design.md`

**Verification note:** This is shell/config plumbing with no unit-test harness. "Tests" here are syntax checks (`bash -n`, `zsh -n`), real `jq`/`cat` merge dry-runs that print to stdout, and `grep` assertions. A full end-to-end run (`./install.sh personal` on a fresh machine) is destructive/environment-specific and is deferred to actual machine setup — it is NOT part of these tasks.

**Pre-task state:** The working tree already has `Brewfile` edited (`cursor` → `cursor-cli`; `nvm` retained) and the spec file, both uncommitted. Task 1's commit picks them up.

---

## File map

**Created:**
- `install-common.sh` — sourced library of core install functions
- `install-work.sh` — work profile entry script
- `install-personal.sh` — personal profile entry script
- `Brewfile.work` — work-only packages
- `Brewfile.personal` — personal-only packages
- `claude/settings.work.json` — Claude Datadog MCP overlay
- `cursor-agent/mcp.work.json` — Cursor-agent Datadog MCP overlay
- `codex/config.work.toml` — Codex Datadog MCP + work project-trust overlay
- `dev/sync-agent-configs.sh` — regenerates merged work agent configs
- `zsh/.zshrc.work` — work-only shell functions

**Modified:**
- `install.sh` — becomes the dispatcher (full rewrite)
- `Brewfile` — core only (remove work + personal packages)
- `claude/settings.json` — remove `datadog` from `mcpServers`
- `cursor-agent/mcp.json` — remove `datadog` from `mcpServers`
- `codex/config.toml` — remove `[mcp_servers.datadog]` + the three `~/work` project-trust tables
- `zsh/.zshrc` — remove work functions, add `~/work`-gated source guard
- `CLAUDE.md`, `GUIDE.md` — document the profile split

---

## Task 1: Split the Brewfile

**Files:**
- Create: `Brewfile.work`
- Create: `Brewfile.personal`
- Modify: `Brewfile`

- [ ] **Step 1: Create `Brewfile.work`**

```ruby
# Work-only packages. Installed by install-work.sh on top of the core Brewfile.
brew "cloudflared"
brew "watchman"
brew "lefthook"
brew "opentofu"
cask "aws-vpn-client"
cask "google-chrome"
cask "ngrok"
cask "slack"
```

- [ ] **Step 2: Create `Brewfile.personal`**

```ruby
# Personal-only packages. Installed by install-personal.sh on top of the core Brewfile.
cask "brave-browser"
cask "tailscale-app"
```

- [ ] **Step 3: Rewrite `Brewfile` to core-only**

Replace the entire contents of `Brewfile` with:

```ruby
tap "cormacrelf/tap"
tap "felixkratz/formulae"
tap "nikitabobko/tap"
brew "gh"
brew "mas"
brew "neovim"
brew "nvm"
brew "tmux"
brew "uv"
brew "cormacrelf/tap/dark-notify"
brew "felixkratz/formulae/borders"
brew "bat"
brew "btop"
brew "eza"
brew "fd"
brew "fzf"
brew "lazydocker"
brew "lazygit"
brew "mise"
brew "ripgrep"
brew "starship"
brew "zoxide"
cask "alacritty"
cask "bitwarden"
cask "chai"
cask "codex"
cask "cursor-cli"
cask "docker-desktop"
cask "font-jetbrains-mono-nerd-font"
cask "kap"
cask "karabiner-elements"
cask "logi-options+"
cask "lunar"
cask "nikitabobko/tap/aerospace"
cask "obsidian"
cask "raycast"
cask "spotify"
cask "ticktick"
```

- [ ] **Step 4: Verify the split — no package lost, no package duplicated**

Run:
```bash
cd ~/.config
diff <(git show HEAD:Brewfile | grep -hE '^(brew|cask) ' | sort) \
     <(cat Brewfile Brewfile.work Brewfile.personal | grep -hE '^(brew|cask) ' | sort)
```
Expected: a single change-pair showing `cask "cursor"` (old) replaced by `cask "cursor-cli"` (new), and nothing else. (The `nvm` line must appear in the new side.)

Run:
```bash
grep -c '^cask "brave-browser"' Brewfile && echo "FAIL: brave still in core" || echo "OK: brave not in core"
grep -q '^cask "tailscale-app"' Brewfile.personal && echo "OK: tailscale in personal"
grep -q '^cask "google-chrome"' Brewfile.work && echo "OK: chrome in work"
```
Expected: `OK` on all three.

- [ ] **Step 5: Commit**

```bash
cd ~/.config
git add Brewfile Brewfile.work Brewfile.personal docs/superpowers/specs/2026-06-15-personal-install-split-design.md docs/superpowers/plans/2026-06-15-personal-install-split.md
git commit -m "feat(install): split Brewfile into core/work/personal profiles

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Strip work bits from agent configs + add overlays + sync helper

**Files:**
- Modify: `claude/settings.json`
- Modify: `cursor-agent/mcp.json`
- Modify: `codex/config.toml`
- Create: `claude/settings.work.json`
- Create: `cursor-agent/mcp.work.json`
- Create: `codex/config.work.toml`
- Create: `dev/sync-agent-configs.sh`

- [ ] **Step 1: Remove `datadog` from `claude/settings.json`**

In `claude/settings.json`, change the `mcpServers` block from:

```json
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--browserUrl",
        "http://127.0.0.1:9222",
        "--isolated"
      ]
    },
    "datadog": {
      "command": "/Users/philip/.config/dev/mcp-datadog.sh"
    }
  },
```
to:
```json
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--browserUrl",
        "http://127.0.0.1:9222",
        "--isolated"
      ]
    }
  },
```

- [ ] **Step 2: Remove `datadog` from `cursor-agent/mcp.json`**

Change `cursor-agent/mcp.json` from:
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--browserUrl",
        "http://127.0.0.1:9222",
        "--isolated"
      ]
    },
    "datadog": {
      "command": "/Users/philip/.config/dev/mcp-datadog.sh"
    }
  }
}
```
to:
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": [
        "-y",
        "chrome-devtools-mcp@latest",
        "--browserUrl",
        "http://127.0.0.1:9222",
        "--isolated"
      ]
    }
  }
}
```

- [ ] **Step 3: Remove work bits from `codex/config.toml`**

Delete these four tables from `codex/config.toml` (the `~/work` project trusts and the datadog MCP). Remove:
```toml
[projects."/Users/philip/work/ledidi-monorepo"]
trust_level = "trusted"
```
```toml
[projects."/Users/philip/work/.dev-stacks"]
trust_level = "trusted"

[projects."/Users/philip/work/scripts"]
trust_level = "trusted"
```
```toml
[mcp_servers.datadog]
command = "/Users/philip/.config/dev/mcp-datadog.sh"
```
KEEP `[projects."/Users/philip/.config"]` and `[mcp_servers.chrome-devtools]`. After editing, the projects section should be only:
```toml
[projects."/Users/philip/.config"]
trust_level = "trusted"
```

- [ ] **Step 4: Create `claude/settings.work.json`**

```json
{
  "mcpServers": {
    "datadog": {
      "command": "/Users/philip/.config/dev/mcp-datadog.sh"
    }
  }
}
```

- [ ] **Step 5: Create `cursor-agent/mcp.work.json`**

```json
{
  "mcpServers": {
    "datadog": {
      "command": "/Users/philip/.config/dev/mcp-datadog.sh"
    }
  }
}
```

- [ ] **Step 6: Create `codex/config.work.toml`**

```toml
[projects."/Users/philip/work/ledidi-monorepo"]
trust_level = "trusted"

[projects."/Users/philip/work/.dev-stacks"]
trust_level = "trusted"

[projects."/Users/philip/work/scripts"]
trust_level = "trusted"

[mcp_servers.datadog]
command = "/Users/philip/.config/dev/mcp-datadog.sh"
```

- [ ] **Step 7: Create `dev/sync-agent-configs.sh`**

```bash
#!/usr/bin/env bash
# Regenerate work agent configs by merging the clean base configs with the
# work-only overlays (Datadog MCP + Codex work project trusts).
#
# Writes REAL files (replacing the personal symlinks) so the work bits are
# never written back through a symlink into the repo. Run on work machines
# after editing any base or overlay agent config.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"

echo "Generating work agent configs..."

# Claude — deep-merge JSON (base * overlay merges mcpServers recursively)
rm -f "$HOME/.claude/settings.json"
jq -s '.[0] * .[1]' \
  "$DOTFILES/claude/settings.json" \
  "$DOTFILES/claude/settings.work.json" \
  > "$HOME/.claude/settings.json"

# Cursor agent — deep-merge JSON
rm -f "$HOME/.cursor/mcp.json"
jq -s '.[0] * .[1]' \
  "$DOTFILES/cursor-agent/mcp.json" \
  "$DOTFILES/cursor-agent/mcp.work.json" \
  > "$HOME/.cursor/mcp.json"

# Codex — independent TOML tables, safe to concatenate (blank line separator)
rm -f "$HOME/.codex/config.toml"
{
  cat "$DOTFILES/codex/config.toml"
  echo
  cat "$DOTFILES/codex/config.work.toml"
} > "$HOME/.codex/config.toml"

echo "Regenerated:"
echo "  ~/.claude/settings.json"
echo "  ~/.cursor/mcp.json"
echo "  ~/.codex/config.toml"
```

- [ ] **Step 8: Make it executable**

Run: `chmod +x ~/.config/dev/sync-agent-configs.sh`

- [ ] **Step 9: Verify the base files are valid and clean**

Run:
```bash
cd ~/.config
jq -e '.mcpServers | has("datadog") | not' claude/settings.json && echo "OK: claude base clean"
jq -e '.mcpServers | has("datadog") | not' cursor-agent/mcp.json && echo "OK: cursor base clean"
jq -e '.mcpServers | has("chrome-devtools")' claude/settings.json >/dev/null && echo "OK: claude keeps chrome"
grep -q 'mcp_servers.datadog' codex/config.toml && echo "FAIL: codex still has datadog" || echo "OK: codex base clean"
grep -q 'work/ledidi-monorepo' codex/config.toml && echo "FAIL: codex still trusts work dir" || echo "OK: codex trusts clean"
```
Expected: all `OK`.

- [ ] **Step 10: Verify the merges produce valid, complete configs (dry run, no install)**

Run:
```bash
cd ~/.config
echo "--- claude merged mcpServers ---"
jq -s '.[0] * .[1]' claude/settings.json claude/settings.work.json | jq '.mcpServers | keys'
echo "--- cursor merged mcpServers ---"
jq -s '.[0] * .[1]' cursor-agent/mcp.json cursor-agent/mcp.work.json | jq '.mcpServers | keys'
echo "--- codex merged (tail) ---"
{ cat codex/config.toml; echo; cat codex/config.work.toml; } | tail -12
```
Expected: both JSON merges list `["chrome-devtools","datadog"]`; the codex tail shows the three work `[projects."...work..."]` tables and `[mcp_servers.datadog]`. Confirm the JSON merge also still contains the other top-level keys: `jq -s '.[0] * .[1]' claude/settings.json claude/settings.work.json | jq 'has("permissions") and has("enabledPlugins")'` → `true`.

- [ ] **Step 11: Commit**

```bash
cd ~/.config
git add claude/settings.json claude/settings.work.json cursor-agent/mcp.json cursor-agent/mcp.work.json codex/config.toml codex/config.work.toml dev/sync-agent-configs.sh
git commit -m "feat(install): extract work-only agent config into overlays

Strip Datadog MCP + Codex work project-trusts from the shared base
configs; add work overlay fragments and dev/sync-agent-configs.sh to
merge them into real files on work machines.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Create `install-common.sh`

**Files:**
- Create: `install-common.sh`

- [ ] **Step 1: Create `install-common.sh`**

```bash
#!/usr/bin/env bash
# Shared core install steps for both the work and personal profiles.
# Sourced by install-work.sh / install-personal.sh — not run directly.

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"

preflight() {
  if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: This script is for macOS only."
    exit 1
  fi
  if [[ "$EUID" -eq 0 ]]; then
    echo "Error: Do not run as root."
    exit 1
  fi
  if [[ ! -f "$DOTFILES/Brewfile" ]]; then
    echo "Error: Expected dotfiles at $DOTFILES (Brewfile not found)."
    echo "Clone the repo first: git clone <repo-url> ~/.config"
    exit 1
  fi
  echo "Setting up from $DOTFILES"
}

install_xcode_clt() {
  if ! xcode-select -p &>/dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Press any key after the installation completes."
    read -n 1 -s
  fi
}

install_homebrew() {
  if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
}

brew_bundle() {
  # $1 = path to a Brewfile
  echo "Installing Homebrew packages from $(basename "$1")..."
  brew bundle --file "$1" --no-lock
}

make_core_dirs() {
  echo "Creating core directory structure..."
  mkdir -p \
    ~/private \
    ~/vaults \
    ~/bin \
    ~/.nvm \
    ~/.cursor \
    ~/.claude \
    ~/.codex/rules \
    ~/.codex/skills \
    ~/.ssh \
    ~/.zsh
}

link_core() {
  echo "Creating core symlinks..."

  # Shell config
  ln -sf "$DOTFILES/zsh/.zshrc" ~/.zshrc

  # SSH config
  if [[ -d ~/.ssh ]]; then
    ln -sf "$DOTFILES/ssh/config" ~/.ssh/config
  fi

  # Cursor editor (GUI) settings
  ln -sf "$DOTFILES/cursor/settings.json" ~/.cursor/settings.json
  ln -sf "$DOTFILES/cursor/keybindings.json" ~/.cursor/keybindings.json

  # Cursor agent (CLI): base mcp.json + statusline.
  # On work, sync-agent-configs.sh replaces mcp.json with a generated file.
  ln -sfn "$DOTFILES/cursor-agent/mcp.json" ~/.cursor/mcp.json
  ln -sf "$DOTFILES/cursor-agent/statusline.sh" ~/.cursor/statusline.sh

  # Claude Code: base settings + agents.
  # On work, sync-agent-configs.sh replaces settings.json with a generated file.
  ln -sf "$DOTFILES/claude/settings.json" ~/.claude/settings.json
  ln -sfn "$DOTFILES/claude/agents" ~/.claude/agents

  # Codex: config + rules symlinked; skills copied (Codex's loader doesn't
  # follow symlinked skill dirs reliably). On work, sync-agent-configs.sh
  # replaces config.toml with a generated file.
  ln -sfn "$DOTFILES/codex/config.toml" ~/.codex/config.toml
  ln -sfn "$DOTFILES/codex/rules/default.rules" ~/.codex/rules/default.rules
  rsync -a --delete "$DOTFILES/codex/skills/code-review/" ~/.codex/skills/code-review/

  # python/pip → python3/pip3 (real commands, not just shell aliases)
  ln -sf /opt/homebrew/bin/python3 ~/bin/python
  ln -sf /opt/homebrew/bin/pip3 ~/bin/pip
}

setup_launch_agents() {
  echo "Installing launch agents..."
  local LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
  mkdir -p "$LAUNCH_AGENTS"
  local plist name label
  for plist in "$DOTFILES"/launchd/*.plist; do
    name="$(basename "$plist")"
    label="${name%.plist}"
    launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
    ln -sf "$plist" "$LAUNCH_AGENTS/$name"
    launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENTS/$name"
  done
}

setup_theme() {
  echo "Setting initial theme..."
  "$DOTFILES/switch-theme.sh"
}

cleanup_stale() {
  # tmux 3.1+ reads from ~/.config/tmux/tmux.conf natively
  if [[ -L ~/.tmux.conf ]]; then
    echo "Removing stale ~/.tmux.conf symlink..."
    rm ~/.tmux.conf
  fi
  # If nvim data exists but isn't a LazyVim setup, clean for fresh bootstrap
  if [[ -d "$HOME/.local/share/nvim" ]] && [[ ! -d "$HOME/.local/share/nvim/lazy/LazyVim" ]]; then
    echo "Cleaning nvim state for LazyVim migration..."
    rm -rf "$HOME/.local/share/nvim"
    rm -rf "$HOME/.local/state/nvim"
    rm -rf "$HOME/.cache/nvim"
  fi
}

install_zsh_autosuggestions() {
  if [[ ! -d "$HOME/.zsh/zsh-autosuggestions" ]]; then
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions"
  fi
}

verify() {
  echo ""
  echo "Verifying installation..."
  echo ""
  local missing=() cmd
  for cmd in nvim tmux lazygit fzf bat eza zoxide starship rg fd gh; do
    if command -v "$cmd" &>/dev/null; then
      printf "  %-12s %s\n" "$cmd" "$(command -v "$cmd")"
    else
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo ""
    echo "  Missing: ${missing[*]}"
  fi
}

# Shared core sequence run by both profiles before their profile-specific layer.
run_core() {
  preflight
  install_xcode_clt
  install_homebrew
  brew_bundle "$DOTFILES/Brewfile"
  make_core_dirs
  link_core
  setup_launch_agents
  setup_theme
  cleanup_stale
  install_zsh_autosuggestions
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n ~/.config/install-common.sh && echo "OK: syntax"`
Expected: `OK: syntax`.

- [ ] **Step 3: Commit**

```bash
cd ~/.config
git add install-common.sh
git commit -m "feat(install): add shared install-common.sh library

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Create `install-work.sh`

**Files:**
- Create: `install-work.sh`

- [ ] **Step 1: Create `install-work.sh`**

```bash
#!/usr/bin/env bash
# Work profile: full Ledidi dev environment on top of the shared core.
set -euo pipefail

DOTFILES="$HOME/.config"
# shellcheck source=install-common.sh
source "$DOTFILES/install-common.sh"

echo "── Installing WORK profile ───────────────────────"

run_core
brew_bundle "$DOTFILES/Brewfile.work"

# Work directories (also the marker that gates zsh/.zshrc.work)
echo "Creating work directory structure..."
mkdir -p \
  ~/work/worktrees \
  ~/work/.dev-stacks

# Dev script symlinks in ~/bin
echo "Linking dev scripts..."
ln -sf "$DOTFILES/dev/dev.sh" ~/bin/dev
ln -sf "$DOTFILES/dev/check.sh" ~/bin/check
ln -sf "$DOTFILES/dev/tests.sh" ~/bin/tests
ln -sf "$DOTFILES/dev/tunnel.sh" ~/bin/tunnel
ln -sf "$DOTFILES/dev/gwc.sh" ~/bin/gwc
ln -sf "$DOTFILES/dev/gwd.sh" ~/bin/gwd
ln -sf "$DOTFILES/dev/sync-context.sh" ~/bin/sync-context
ln -sf "$DOTFILES/dev/fix.sh" ~/bin/fix
ln -sf "$DOTFILES/dev/sync-agent-configs.sh" ~/bin/sync-agent-configs

# Generate work agent configs (Datadog MCP + Codex work project-trusts)
"$DOTFILES/dev/sync-agent-configs.sh"

verify

cat <<'EOF'

Work setup complete. Manual follow-up:

  1. Restore ~/.ssh keys
  2. Create ~/.config/zsh/.zsh_secrets (incl. DD_API_KEY / DD_APP_KEY)
  3. Sign in to GitHub: gh auth login
  4. Install and sign in to Docker Desktop
  5. Sign in to Cursor, Claude, Slack, AWS VPN, etc.
  6. Install Node: nvm install 24 && nvm alias default 24
  7. Start background services:
       brew services start felixkratz/formulae/borders
       open -a AeroSpace
       open -a Karabiner-Elements
       open -a Raycast
  8. Launch nvim once to bootstrap LazyVim plugins
  9. Reload shell: exec zsh -l
EOF
```

- [ ] **Step 2: Make it executable + verify syntax**

Run:
```bash
chmod +x ~/.config/install-work.sh
bash -n ~/.config/install-work.sh && echo "OK: syntax"
```
Expected: `OK: syntax`.

- [ ] **Step 3: Commit**

```bash
cd ~/.config
git add install-work.sh
git commit -m "feat(install): add work profile entry script

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Create `install-personal.sh`

**Files:**
- Create: `install-personal.sh`

- [ ] **Step 1: Create `install-personal.sh`**

```bash
#!/usr/bin/env bash
# Personal profile: core environment with no work tooling.
set -euo pipefail

DOTFILES="$HOME/.config"
# shellcheck source=install-common.sh
source "$DOTFILES/install-common.sh"

echo "── Installing PERSONAL profile ───────────────────"

run_core
brew_bundle "$DOTFILES/Brewfile.personal"

verify

cat <<'EOF'

Personal setup complete. Manual follow-up:

  1. Restore ~/.ssh keys
  2. Create ~/.config/zsh/.zsh_secrets
  3. Sign in to GitHub: gh auth login
  4. Install and sign in to Docker Desktop
  5. Sign in to Brave, Claude, Tailscale, etc.
  6. Install Node: nvm install 24 && nvm alias default 24
  7. Start background services:
       brew services start felixkratz/formulae/borders
       open -a AeroSpace
       open -a Karabiner-Elements
       open -a Raycast
  8. Launch nvim once to bootstrap LazyVim plugins
  9. Reload shell: exec zsh -l
EOF
```

- [ ] **Step 2: Make it executable + verify syntax**

Run:
```bash
chmod +x ~/.config/install-personal.sh
bash -n ~/.config/install-personal.sh && echo "OK: syntax"
```
Expected: `OK: syntax`.

- [ ] **Step 3: Commit**

```bash
cd ~/.config
git add install-personal.sh
git commit -m "feat(install): add personal profile entry script

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Rewrite `install.sh` as the dispatcher

**Files:**
- Modify: `install.sh` (full replacement)

- [ ] **Step 1: Replace the entire contents of `install.sh`**

```bash
#!/usr/bin/env bash
# Dispatcher: pick an install profile and hand off to its entry script.
#   ./install.sh work       — full Ledidi dev environment
#   ./install.sh personal   — personal machine, no work tooling
set -euo pipefail

DOTFILES="$HOME/.config"
profile="${1:-}"

case "$profile" in
  work|personal)
    exec "$DOTFILES/install-$profile.sh"
    ;;
  *)
    echo "Usage: $(basename "$0") work|personal" >&2
    echo "" >&2
    echo "  work      full dev environment (Ledidi monorepo, dev scripts, work apps)" >&2
    echo "  personal  personal machine (no work tooling)" >&2
    exit 1
    ;;
esac
```

- [ ] **Step 2: Verify syntax + arg handling**

Run:
```bash
bash -n ~/.config/install.sh && echo "OK: syntax"
bash ~/.config/install.sh 2>&1 | grep -q "Usage:" && echo "OK: rejects missing arg"
bash ~/.config/install.sh bogus 2>&1 | grep -q "Usage:" && echo "OK: rejects bad arg"
```
Expected: three `OK` lines. (These invocations hit the usage branch and exit before any install action.)

- [ ] **Step 3: Commit**

```bash
cd ~/.config
git add install.sh
git commit -m "feat(install): turn install.sh into work|personal dispatcher

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Extract work shell functions to `zsh/.zshrc.work`

**Files:**
- Create: `zsh/.zshrc.work`
- Modify: `zsh/.zshrc`

- [ ] **Step 1: Create `zsh/.zshrc.work`**

```zsh
# Work dev environment — git worktrees, dev stack, monorepo tooling.
# Sourced from .zshrc only when ~/work exists (work profile). compdef calls
# rely on compinit having already run in .zshrc before this file is sourced.

# Git & worktrees

gwc() {
  /Users/philip/.config/dev/gwc.sh "$@"
}

_gwc_completions() {
  case "$words[CURRENT-1]" in
    -b|--base)
      local refs=($(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null))
      _describe 'base ref' refs
      ;;
    *)
      local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
      _describe 'branch' branches
      ;;
  esac
}
compdef _gwc_completions gwc

gwd() {
  /Users/philip/.config/dev/gwd.sh "$@"
}

_gwd_completions() {
  local dir="/Users/philip/work/worktrees"
  local worktrees=(${(@f)"$(ls "$dir" 2>/dev/null)"})
  _describe 'worktree' worktrees
}
compdef _gwd_completions gwd

sync-context() {
  /Users/philip/.config/dev/sync-context.sh "$@"
}

# Dev tools

dev() {
  /Users/philip/.config/dev/dev.sh "$@"
}

_dev_completions() {
  local commands=("up" "down" "stop" "start" "restart" "nuke" "status" "exec" "logs" "ps" "build")
  _describe 'command' commands
}
compdef _dev_completions dev

check() {
  /Users/philip/.config/dev/check.sh "$@"
}

_check_completions() {
  local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
  _describe 'branch' branches
}
compdef _check_completions check

_tests_completions() {
  local suites=("frontend:Frontend unit tests (Vitest)" "registries:Registries service tests (Jest)" "e2e:Frontend E2E tests (Playwright)")
  _describe 'suite' suites
}
compdef _tests_completions tests

fix() {
  /Users/philip/.config/dev/fix.sh "$@"
}

_fix_completions() {
  local cmds=("build:Rebuild Docker images" "full:npm install + rebuild")
  _describe 'command' cmds
}
compdef _fix_completions fix

prisma() {
  local monorepo_root
  monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not inside a git repository"
    return 1
  }
  local project_name slot worktree_slot_file
  project_name="$(basename "$monorepo_root")"
  worktree_slot_file="${DEV_STACKS_DIR:-$HOME/work/.dev-stacks}/$project_name/worktree-slot"
  if [[ -f "$worktree_slot_file" ]]; then
    slot=$(cat "$worktree_slot_file")
  else
    slot=0
  fi
  local port=$((5432 + slot * 100))
  (cd "$monorepo_root/services/registries" &&
    POSTGRES_URL="postgresql://postgres:postgres@localhost:$port/registries" \
      npx prisma studio "$@")
}
```

- [ ] **Step 2: Remove the gwc/gwd/sync-context block from `zsh/.zshrc`**

Delete this exact block (currently lines 94-125) from `zsh/.zshrc`:
```zsh
gwc() {
  /Users/philip/.config/dev/gwc.sh "$@"
}

_gwc_completions() {
  case "$words[CURRENT-1]" in
    -b|--base)
      local refs=($(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null))
      _describe 'base ref' refs
      ;;
    *)
      local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
      _describe 'branch' branches
      ;;
  esac
}
compdef _gwc_completions gwc

gwd() {
  /Users/philip/.config/dev/gwd.sh "$@"
}

_gwd_completions() {
  local dir="/Users/philip/work/worktrees"
  local worktrees=(${(@f)"$(ls "$dir" 2>/dev/null)"})
  _describe 'worktree' worktrees
}
compdef _gwd_completions gwd

sync-context() {
  /Users/philip/.config/dev/sync-context.sh "$@"
}
```
The `# Git & worktrees` header (line 92) stays — the `# Git alias completions` block that follows it remains under it.

- [ ] **Step 3: Remove the `# Dev tools` block from `zsh/.zshrc`**

Delete this exact block (currently lines 142-198) from `zsh/.zshrc`:
```zsh
# Dev tools

dev() {
  /Users/philip/.config/dev/dev.sh "$@"
}

_dev_completions() {
  local commands=("up" "down" "stop" "start" "restart" "nuke" "status" "exec" "logs" "ps" "build")
  _describe 'command' commands
}
compdef _dev_completions dev

check() {
  /Users/philip/.config/dev/check.sh "$@"
}

_check_completions() {
  local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
  _describe 'branch' branches
}
compdef _check_completions check

_tests_completions() {
  local suites=("frontend:Frontend unit tests (Vitest)" "registries:Registries service tests (Jest)" "e2e:Frontend E2E tests (Playwright)")
  _describe 'suite' suites
}
compdef _tests_completions tests

fix() {
  /Users/philip/.config/dev/fix.sh "$@"
}

_fix_completions() {
  local cmds=("build:Rebuild Docker images" "full:npm install + rebuild")
  _describe 'command' cmds
}
compdef _fix_completions fix

prisma() {
  local monorepo_root
  monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not inside a git repository"
    return 1
  }
  local project_name slot worktree_slot_file
  project_name="$(basename "$monorepo_root")"
  worktree_slot_file="${DEV_STACKS_DIR:-$HOME/work/.dev-stacks}/$project_name/worktree-slot"
  if [[ -f "$worktree_slot_file" ]]; then
    slot=$(cat "$worktree_slot_file")
  else
    slot=0
  fi
  local port=$((5432 + slot * 100))
  (cd "$monorepo_root/services/registries" &&
    POSTGRES_URL="postgresql://postgres:postgres@localhost:$port/registries" \
      npx prisma studio "$@")
}
```
After this deletion, the `# Git alias completions` block (which stays) is followed directly by the `# Utilities` block (`notify`, `docker`, `no-sleep`).

- [ ] **Step 4: Add the `~/work`-gated source guard to the end of `zsh/.zshrc`**

Append to the very end of `zsh/.zshrc`:
```zsh

# ── Work profile (only present/sourced on work machines) ────
[ -d "$HOME/work" ] && [ -f "$HOME/.config/zsh/.zshrc.work" ] && \
  source "$HOME/.config/zsh/.zshrc.work"
```

- [ ] **Step 5: Verify syntax of both files**

Run:
```bash
zsh -n ~/.config/zsh/.zshrc && echo "OK: .zshrc syntax"
zsh -n ~/.config/zsh/.zshrc.work && echo "OK: .zshrc.work syntax"
```
Expected: both `OK`.

- [ ] **Step 6: Verify the functions moved (not duplicated, not lost)**

Run (patterns anchor on `^name()` — the definition line — so they count each function exactly once):
```bash
cd ~/.config
echo "--- work functions: want .zshrc=0, .zshrc.work=1 ---"
for fn in gwc gwd 'sync-context' dev check fix prisma _tests_completions _dev_completions; do
  echo "$fn: .zshrc=$(grep -cE "^${fn}\(\)" zsh/.zshrc) .zshrc.work=$(grep -cE "^${fn}\(\)" zsh/.zshrc.work)"
done
echo "--- core functions: want .zshrc=1 ---"
for fn in notify docker no-sleep eff; do
  echo "$fn: .zshrc=$(grep -cE "^${fn}\(\)" zsh/.zshrc)"
done
grep -q 'zshrc.work' zsh/.zshrc && echo "OK: source guard present"
```
Expected: every work function shows `.zshrc=0 .zshrc.work=1`; every core function shows `.zshrc=1`; source guard present.

- [ ] **Step 7: Commit**

```bash
cd ~/.config
git add zsh/.zshrc zsh/.zshrc.work
git commit -m "feat(install): extract work shell functions to ~/work-gated .zshrc.work

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Update documentation

**Files:**
- Modify: `CLAUDE.md`
- Modify: `GUIDE.md`

- [ ] **Step 1: Update the `install.sh` bullet in `CLAUDE.md`**

In `CLAUDE.md`, under "Repository Structure", replace the existing `install.sh` bullet:
```markdown
- `install.sh` — Idempotent bootstrap script (brew, dirs, symlinks, cleanup, verification)
```
with:
```markdown
- `install.sh` / `install-common.sh` / `install-work.sh` / `install-personal.sh` — Profile-based bootstrap. `./install.sh work|personal` dispatches to the matching entry script; both source `install-common.sh` (brew, core dirs, symlinks, launch agents, theme, cleanup, verification) then layer profile-specific packages and links. Idempotent.
- `Brewfile` / `Brewfile.work` / `Brewfile.personal` — Core packages plus per-profile package sets. Work adds Ledidi/dev tooling (cloudflared, watchman, lefthook, opentofu, aws-vpn-client, Chrome, ngrok, Slack); personal adds Brave + Tailscale.
```

- [ ] **Step 2: Document the agent-config extraction in `CLAUDE.md`**

In `CLAUDE.md`, under "Key Patterns", add this bullet after the "Multi-agent parity" paragraph:
```markdown
**Work agent config**: The base `claude/settings.json`, `codex/config.toml`, and `cursor-agent/mcp.json` hold only shared content. Work-only bits (Datadog MCP, Codex `~/work` project-trusts) live in `*.work.*` overlay files and are merged into real (non-symlink) live files on work machines by `dev/sync-agent-configs.sh` (run by `install-work.sh`; re-run after editing a base/overlay on a work machine). On personal machines the base files stay symlinked. Work shell functions (`gwc`/`gwd`/`dev`/`check`/`fix`/`prisma`/`sync-context`) live in `zsh/.zshrc.work`, sourced by `.zshrc` only when `~/work` exists.
```

- [ ] **Step 3: Update `install.sh` references in `GUIDE.md`**

Run to find any references:
```bash
grep -n 'install.sh' ~/.config/GUIDE.md
```
For each hit that shows the bare `./install.sh` bootstrap command, update it to `./install.sh work` (or `personal`). If there are no hits, skip this step (no change needed).

- [ ] **Step 4: Verify the docs mention the new entry points**

Run:
```bash
cd ~/.config
grep -q 'install-work.sh' CLAUDE.md && echo "OK: CLAUDE.md mentions install-work.sh"
grep -q 'Brewfile.personal' CLAUDE.md && echo "OK: CLAUDE.md mentions Brewfile.personal"
grep -q 'sync-agent-configs' CLAUDE.md && echo "OK: CLAUDE.md mentions sync-agent-configs"
```
Expected: three `OK`.

- [ ] **Step 5: Commit**

```bash
cd ~/.config
git add CLAUDE.md GUIDE.md
git commit -m "docs: describe work|personal install profiles

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Final verification (after all tasks)

- [ ] **Step 1: All scripts pass syntax checks**

```bash
cd ~/.config
for f in install.sh install-common.sh install-work.sh install-personal.sh dev/sync-agent-configs.sh; do
  bash -n "$f" && echo "OK: $f"
done
zsh -n zsh/.zshrc && zsh -n zsh/.zshrc.work && echo "OK: zsh files"
```
Expected: `OK` for every file.

- [ ] **Step 2: Agent config merges still valid end-to-end**

```bash
cd ~/.config
jq -s '.[0] * .[1] | .mcpServers | keys' claude/settings.json claude/settings.work.json
jq -s '.[0] * .[1] | .mcpServers | keys' cursor-agent/mcp.json cursor-agent/mcp.work.json
```
Expected: each prints `["chrome-devtools","datadog"]`.

- [ ] **Step 3: Confirm clean working tree**

```bash
cd ~/.config && git status --short
```
Expected: empty (everything committed).

**Reminder:** A real install run (`./install.sh personal` / `work`) on an actual machine is the ultimate test but is out of scope here — it installs packages and rewrites `~` symlinks. Do not run it as part of plan execution.
