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
