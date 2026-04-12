#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.config"

# ─── Pre-flight ───────────────────────────────────────────────

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

# ─── Xcode Command Line Tools ────────────────────────────────

if ! xcode-select -p &>/dev/null; then
  echo "Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "Press any key after the installation completes."
  read -n 1 -s
fi

# ─── Homebrew ─────────────────────────────────────────────────

if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

echo "Installing Homebrew packages..."
brew bundle --file "$DOTFILES/Brewfile" --no-lock

# ─── Directory Structure ─────────────────────────────────────

echo "Creating directory structure..."
mkdir -p \
  ~/work/worktrees \
  ~/work/.dev-stacks \
  ~/private \
  ~/vaults \
  ~/bin \
  ~/.nvm \
  ~/.cursor \
  ~/.claude \
  ~/.ssh \
  ~/.zsh

# ─── Symlinks ────────────────────────────────────────────────

echo "Creating symlinks..."

# Shell config
ln -sf "$DOTFILES/zsh/.zshrc" ~/.zshrc

# SSH config
if [[ -d ~/.ssh ]]; then
  ln -sf "$DOTFILES/ssh/config" ~/.ssh/config
fi

# Cursor editor config
ln -sf "$DOTFILES/cursor/settings.json" ~/.cursor/settings.json
ln -sf "$DOTFILES/cursor/keybindings.json" ~/.cursor/keybindings.json

# Dev scripts in ~/bin
ln -sf "$DOTFILES/dev/dev.sh" ~/bin/dev
ln -sf "$DOTFILES/dev/check.sh" ~/bin/check
ln -sf "$DOTFILES/dev/tests.sh" ~/bin/tests
ln -sf "$DOTFILES/dev/tunnel.sh" ~/bin/tunnel
ln -sf "$DOTFILES/dev/gwc.sh" ~/bin/gwc
ln -sf "$DOTFILES/dev/gwd.sh" ~/bin/gwd
ln -sf "$DOTFILES/dev/sync-context.sh" ~/bin/sync-context
ln -sf "$DOTFILES/dev/fix.sh" ~/bin/fix

# ─── Launch Agents ───────────────────────────────────────────

echo "Installing launch agents..."
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS"

for plist in "$DOTFILES"/launchd/*.plist; do
  name="$(basename "$plist")"
  label="${name%.plist}"
  # Unload first if already loaded (ignore errors on fresh install)
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
  ln -sf "$plist" "$LAUNCH_AGENTS/$name"
  launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENTS/$name"
done

# ─── Theme ───────────────────────────────────────────────────

echo "Setting initial theme..."
"$DOTFILES/switch-theme.sh"

# ─── Cleanup Stale Symlinks ──────────────────────────────────

# tmux 3.1+ reads from ~/.config/tmux/tmux.conf natively
if [[ -L ~/.tmux.conf ]]; then
  echo "Removing stale ~/.tmux.conf symlink (tmux reads from ~/.config/tmux/tmux.conf directly)"
  rm ~/.tmux.conf
fi

# ─── Neovim Cache ────────────────────────────────────────────

# If nvim data exists but isn't a LazyVim setup, clean for fresh bootstrap
if [[ -d "$HOME/.local/share/nvim" ]] && [[ ! -d "$HOME/.local/share/nvim/lazy/LazyVim" ]]; then
  echo "Cleaning nvim state for LazyVim migration..."
  rm -rf "$HOME/.local/share/nvim"
  rm -rf "$HOME/.local/state/nvim"
  rm -rf "$HOME/.cache/nvim"
fi

# ─── zsh-autosuggestions ─────────────────────────────────────

if [[ ! -d "$HOME/.zsh/zsh-autosuggestions" ]]; then
  echo "Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$HOME/.zsh/zsh-autosuggestions"
fi

# ─── Verification ────────────────────────────────────────────

echo ""
echo "Verifying installation..."
echo ""

missing=()
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

# ─── Done ─────────────────────────────────────────────────────

echo ""
echo "Setup complete. Manual follow-up:"
echo ""
echo "  1. Restore ~/.ssh keys"
echo "  2. Create ~/.config/zsh/.zsh_secrets"
echo "  3. Sign in to GitHub: gh auth login"
echo "  4. Install and sign in to Docker Desktop"
echo "  5. Sign in to Cursor, Claude Desktop, Brave, etc."
echo "  6. Install Node: nvm install 24 && nvm alias default 24"
echo "  7. Start background services:"
echo "       brew services start felixkratz/formulae/borders"
echo "       open -a AeroSpace"
echo "       open -a Karabiner-Elements"
echo "       open -a Raycast"
echo "  8. Launch nvim once to bootstrap LazyVim plugins"
echo "  9. Reload shell: exec zsh -l"
echo ""
