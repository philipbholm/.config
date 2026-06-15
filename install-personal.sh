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
