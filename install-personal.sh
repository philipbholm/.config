#!/usr/bin/env bash
# Personal profile: core environment with no work tooling.
set -euo pipefail

DOTFILES="$HOME/.config"
# shellcheck source=install-common.sh
source "$DOTFILES/install-common.sh"

echo "── Installing PERSONAL profile ───────────────────"

run_core
brew_bundle "$DOTFILES/Brewfile.personal"
setup_macos_defaults

verify

cat <<'EOF'

Personal setup complete. Manual follow-up:

  1. Set up Karabiner-Elements, AeroSpace, Raycast, Brave, and Chai
  2. Restore ~/.ssh keys (github)
  3. Create ~/.config/zsh/.zsh_secrets
  4. Sign in to GitHub: gh auth login
  5. Install and sign in to Docker Desktop
  6. Install Node: nvm install --lts --latest-npm && nvm alias default 'lts/*'
  7. Launch nvim once to bootstrap LazyVim plugins
  8. Reload shell: exec zsh -l
EOF
