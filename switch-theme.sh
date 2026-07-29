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

# Hourly no-arg runs (see launchd/com.philip.theme-watcher.plist) mean most
# invocations change nothing: skip the apply steps when both the appearance and
# the theme file already match, so borders isn't restarted for no reason.
# An explicit light/dark argument always applies (it doubles as a re-kick).
if [ -z "${1:-}" ] && cmp -s "$THEME_DIR/$MODE.toml" "$ACTIVE_THEME" 2>/dev/null; then
  STYLE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light)
  if { [ "$MODE" = dark ] && [ "$STYLE" = Dark ]; } ||
     { [ "$MODE" = light ] && [ "$STYLE" = Light ]; }; then
    exit 0
  fi
fi

# Fixed schedule: keep macOS's own sunset/sunrise switching off so it can't
# override us between our hourly runs.
defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false
osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $DARK"

# Copy (never symlink) the theme: alacritty's live_config_reload canonicalizes
# import paths and watches the resolved file, so a symlink swap emits no event.
# rm first — cp/redirect onto an existing symlink would write through to the
# theme file itself.
rm -f "$ACTIVE_THEME"
cp "$THEME_DIR/$MODE.toml" "$ACTIVE_THEME"
touch "$HOME/.config/alacritty/alacritty.toml"

# Reload borders so it picks up the appearance we just set (bordersrc with no
# argument reads AppleInterfaceStyle).
#
# Do NOT call bordersrc directly: `borders` is a long-running daemon that runs
# in the foreground (which is what com.philip.borders expects of it), so
# invoking it here never returns — it hangs the caller and leaks a second
# daemon. Restarting the launch agent applies the config and returns at once.
if ! launchctl kickstart -k "gui/$(id -u)/com.philip.borders" 2>/dev/null; then
  # Agent not loaded (e.g. first install before launch agents are set up).
  "$HOME/.config/borders/bordersrc" "$MODE" &
fi
