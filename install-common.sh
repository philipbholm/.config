#!/usr/bin/env bash
# Shared core install steps for both the work and personal profiles.
# Sourced by install-work.sh / install-personal.sh — not run directly.

set -euo pipefail
trap 'echo "Error: command failed (line $LINENO): $BASH_COMMAND" >&2' ERR

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

keep_sudo_alive() {
  echo "Caching sudo credentials for the rest of this run..."
  sudo -v
  ( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
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
  local taps tap
  taps=$(grep -oE '^tap "[^"]+"' "$1" | cut -d'"' -f2 || true)
  if [[ -n "$taps" ]]; then
    echo "Trusting third-party taps in $(basename "$1")..."
    while IFS= read -r tap; do
      brew trust --tap "$tap"
    done <<< "$taps"
  fi
  echo "Installing Homebrew packages from $(basename "$1")..."
  brew bundle install --file "$1"
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

  # SSH config (base = personal: github only).
  # install-work.sh relinks this to ssh/config.work.
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

  # claude-notify: Telegram on/off switch + Stop/Notification hook handler.
  ln -sf "$DOTFILES/dev/claude-notify.sh" ~/bin/claude-notify

  # Codex: config + rules symlinked; skills copied (Codex's loader doesn't
  # follow symlinked skill dirs reliably). On work, sync-agent-configs.sh
  # replaces config.toml with a generated file.
  ln -sfn "$DOTFILES/codex/config.toml" ~/.codex/config.toml
  ln -sfn "$DOTFILES/codex/rules/default.rules" ~/.codex/rules/default.rules
  for skill_dir in "$DOTFILES"/codex/skills/*/; do
    rsync -a --delete "$skill_dir" ~/.codex/skills/"$(basename "$skill_dir")"/
  done

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
  if ! "$DOTFILES/switch-theme.sh"; then
    echo "Warning: switch-theme.sh failed — likely needs Automation permission for" >&2
    echo "System Events (System Settings > Privacy & Security > Automation > Terminal)." >&2
    echo "Grant it and re-run switch-theme.sh manually later. Continuing setup..." >&2
  fi
}

setup_macos_defaults() {
  echo "Configuring macOS defaults (Dock, battery, keyboard, Finder)..."

  # Dock: autohide + pinned app list, in order. Apps not yet installed are
  # skipped rather than added as broken icons; re-run after installing them.
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock persistent-apps -array
  local dock_apps=(
    "/Applications/Alacritty.app"
    "/Applications/Docker.app"
    "/Applications/Spotify.app"
    "/Applications/TickTick.app"
    "/Applications/Obsidian.app"
    "/Applications/Brave Browser.app"
  )
  local app
  for app in "${dock_apps[@]}"; do
    if [[ -d "$app" ]]; then
      defaults write com.apple.dock persistent-apps -array-add \
        "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    else
      echo "  Skipping Dock entry for $app (not installed)"
    fi
  done

  # Menu bar: show battery percentage (legacy key + Ventura+ Control Center key)
  defaults write com.apple.menuextra.battery ShowPercent -string "YES"
  defaults write com.apple.controlcenter BatteryShowPercentage -bool true

  # Keyboard: fast key repeat
  defaults write NSGlobalDomain KeyRepeat -int 2
  defaults write NSGlobalDomain InitialKeyRepeat -int 15

  # Finder: show hidden files and all filename extensions
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true

  killall cfprefsd &>/dev/null || true
  killall Dock &>/dev/null || true
  killall Finder &>/dev/null || true
  killall SystemUIServer &>/dev/null || true
  killall ControlCenter &>/dev/null || true
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
  keep_sudo_alive
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
