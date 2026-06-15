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
