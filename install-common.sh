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

install_node() {
  local nvm_sh
  nvm_sh="$(brew --prefix nvm 2>/dev/null)/nvm.sh"
  if [[ ! -s "$nvm_sh" ]]; then
    echo "Warning: nvm not found at $nvm_sh — skipping Node install." >&2
    return 0
  fi

  # nvm.sh is not written for `set -euo pipefail`; relax while it is loaded.
  export NVM_DIR="$HOME/.nvm"
  set +eu
  # shellcheck disable=SC1090
  . "$nvm_sh"
  if [[ "$(nvm version default)" == v* ]]; then
    echo "Node already installed (default: $(nvm version default))"
  else
    echo "Installing Node LTS via nvm..."
    nvm install --lts --latest-npm
    nvm alias default 'lts/*'
  fi
  nvm use default >/dev/null
  set -eu
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

# Populate a ~/.claude subdirectory with one symlink per entry of the given
# source dirs:  link_claude_dir <dest> <src_dir>...
# Per-entry rather than one symlink for the whole directory, so the work-only
# sets (claude/skills.work, claude/agents.work) can be layered on by
# install-work.sh and stay off personal machines. Each run is a full reset of
# the links this function manages.
link_claude_dir() {
  local dest="$1"
  shift

  # Older installs symlinked the whole directory — replace it with a real dir.
  if [[ -L "$dest" ]]; then
    rm "$dest"
  fi
  mkdir -p "$dest"

  # Drop links made by a previous run (a work skill/agent left behind after a
  # personal reinstall would otherwise linger). Anything else is machine-local
  # and is left alone.
  local link
  for link in "$dest"/*; do
    if [[ -L "$link" && "$(readlink "$link")" == "$DOTFILES/claude/"* ]]; then
      rm "$link"
    fi
  done

  # Entries are skill directories or agent .md files depending on the caller.
  local src_dir entry
  for src_dir in "$@"; do
    for entry in "$src_dir"/*; do
      [[ -e "$entry" ]] || continue
      ln -sfn "$entry" "$dest/$(basename "$entry")"
    done
  done
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

  # Claude Code: base settings + agents + skills + statusline.
  # On work, sync-agent-configs.sh replaces settings.json with a generated file.
  ln -sf "$DOTFILES/claude/settings.json" ~/.claude/settings.json
  ln -sf "$DOTFILES/claude/statusline-command.sh" ~/.claude/statusline-command.sh

  # Shared skills/agents only. install-work.sh re-links with the .work sets
  # added; claude/agents is currently empty (every agent is Ledidi-specific).
  link_claude_dir ~/.claude/skills "$DOTFILES/claude/skills"
  link_claude_dir ~/.claude/agents "$DOTFILES/claude/agents"

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
  # Prune agents whose repo plist was removed (now-broken symlinks into launchd/)
  for plist in "$LAUNCH_AGENTS"/com.philip.*.plist; do
    if [ -L "$plist" ] && [ ! -e "$plist" ]; then
      label="$(basename "${plist%.plist}")"
      launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
      rm -f "$plist"
    fi
  done
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

bootstrap_nvim() {
  if ! command -v nvim &>/dev/null; then
    echo "Warning: nvim not installed — skipping LazyVim bootstrap." >&2
    return 0
  fi
  echo "Bootstrapping LazyVim plugins (this can take a minute)..."
  if ! nvim --headless "+Lazy! sync" +qa 2>/dev/null; then
    echo "Warning: LazyVim bootstrap failed — launch nvim manually to retry." >&2
  fi
}

verify() {
  echo ""
  echo "Verifying installation..."
  echo ""
  local missing=() cmd
  for cmd in nvim tmux lazygit fzf bat eza zoxide starship rg fd gh node npm npx python3 terminal-notifier; do
    if command -v "$cmd" &>/dev/null; then
      printf "  %-16s %s\n" "$cmd" "$(command -v "$cmd")"
    else
      missing+=("$cmd")
    fi
  done

  # Paths that must resolve for the shell/agent configs to work at all
  # (~/.claude/agents is a real dir; it is empty on the personal profile)
  local link
  for link in ~/.zshrc ~/.claude/settings.json ~/.claude/agents \
              ~/.claude/skills/explain-diff-html \
              ~/.claude/statusline-command.sh ~/.codex/config.toml ~/.cursor/mcp.json \
              ~/bin/python ~/bin/pip; do
    if [[ ! -e "$link" ]]; then
      missing+=("$link")
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
  install_node
  link_core
  setup_launch_agents
  setup_theme
  cleanup_stale
  install_zsh_autosuggestions
  bootstrap_nvim
}
