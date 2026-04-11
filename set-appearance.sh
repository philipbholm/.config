#!/bin/bash
# Set macOS appearance and sync terminal/borders theme
# Usage: set-appearance.sh dark|light

set -euo pipefail

MODE="${1:-}"

case "$MODE" in
  dark)
    osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
    ;;
  light)
    osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
    ;;
  *)
    echo "Usage: set-appearance.sh dark|light" >&2
    exit 1
    ;;
esac

# Sync alacritty theme + borders to match
"$HOME/.config/switch-theme.sh"
