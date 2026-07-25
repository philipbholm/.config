#!/usr/bin/env bash
# Work profile: full Ledidi dev environment on top of the shared core.
set -euo pipefail

DOTFILES="$HOME/.config"
# shellcheck source=install-common.sh
source "$DOTFILES/install-common.sh"

echo "── Installing WORK profile ───────────────────────"

run_core
brew_bundle "$DOTFILES/Brewfile.work"
setup_macos_defaults

# Work directories (also the marker that gates zsh/.zshrc.work)
echo "Creating work directory structure..."
mkdir -p \
  ~/work/worktrees \
  ~/work/.dev-stacks

# Work SSH config (github_work key + bitbucket), replacing the personal base
if [[ -d ~/.ssh ]]; then
  ln -sf "$DOTFILES/ssh/config.work" ~/.ssh/config
fi

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

  1. Set up Karabiner-Elements, AeroSpace, and Raycast
  2. Restore ~/.ssh keys (github_work, bitbucket)
  3. Create ~/.config/zsh/.zsh_secrets (incl. DD_API_KEY / DD_APP_KEY)
  4. Sign in to GitHub: gh auth login
  5. Install and sign in to Docker Desktop
  6. Sign in to Cursor, Claude, Slack, AWS VPN, etc.
  7. Install Node: nvm install --lts --latest-npm && nvm alias default 'lts/*'
  8. Start background services:
       brew services start felixkratz/formulae/borders
  9. Launch nvim once to bootstrap LazyVim plugins
  10. Reload shell: exec zsh -l
EOF
