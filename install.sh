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
