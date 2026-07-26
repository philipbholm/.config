#!/bin/bash
# Sync macOS appearance + alacritty + borders to light/dark.
# tmux needs no step: its colors are ANSI palette entries, so it follows alacritty.
# Usage: switch-theme.sh [light|dark]
# No argument: derive mode from local machine time (light 07:00-18:00).
set -euo pipefail

THEME_DIR="$HOME/.config/alacritty/themes"
ACTIVE_THEME="$HOME/.config/alacritty/active_theme.toml"

MODE="${1:-}"
if [ -z "$MODE" ]; then
  HOUR=$(date +%-H)
  if [ "$HOUR" -ge 18 ] || [ "$HOUR" -lt 7 ]; then
    MODE=dark
  else
    MODE=light
  fi
fi

case "$MODE" in
  dark) DARK=true ;;
  light) DARK=false ;;
  *)
    echo "Usage: switch-theme.sh [light|dark]" >&2
    exit 1
    ;;
esac

# Fixed schedule: keep macOS's own sunset/sunrise switching off so it can't
# override us between our 07:00/19:00 runs.
defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false
osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $DARK"

# Copy (never symlink) the theme: alacritty's live_config_reload canonicalizes
# import paths and watches the resolved file, so a symlink swap emits no event.
# rm first — cp/redirect onto an existing symlink would write through to the
# theme file itself.
rm -f "$ACTIVE_THEME"
cp "$THEME_DIR/$MODE.toml" "$ACTIVE_THEME"
touch "$HOME/.config/alacritty/alacritty.toml"

# Re-invoking borders updates the running instance's colors in place.
"$HOME/.config/borders/bordersrc" "$MODE"
