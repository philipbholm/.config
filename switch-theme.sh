#!/bin/bash
# Sync macOS appearance + alacritty + borders to light/dark.
# Usage: switch-theme.sh [light|dark]
# No argument: derive mode from local machine time (light 07:00-18:00).
set -euo pipefail

# launchd does not load the shell's Homebrew PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

THEME_DIR="$HOME/.config/alacritty/themes"
ACTIVE_THEME="$HOME/.config/alacritty/active_theme.toml"

refresh_tmux_colors() {
  local CLIENTS SOCKET ATTEMPT READY CLIENT_TERM CLIENT_TTY SOCKET_FOUND=false
  command -v tmux >/dev/null || return 0
  CLIENTS=$(tmux list-clients -F '#{client_termname} #{client_tty}' 2>/dev/null) || return 0
  [[ "$CLIENTS" == *alacritty* ]] || return 0

  # File reload is asynchronous. Wait for each Alacritty process to apply the
  # theme before asking the attached terminals for their default colors.
  for SOCKET in "${TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR)}"/Alacritty-*.sock; do
    [[ -S "$SOCKET" ]] || continue
    SOCKET_FOUND=true
    READY=false
    for ((ATTEMPT = 0; ATTEMPT < 30; ATTEMPT++)); do
      if alacritty msg --socket "$SOCKET" get-config --window-id -1 |
        python3 -c '
import json, sys, tomllib
with open(sys.argv[1], "rb") as theme_file:
    expected = tomllib.load(theme_file)["colors"]["primary"]
actual = json.load(sys.stdin)["colors"]["primary"]
sys.exit(not all(actual[key] == value for key, value in expected.items()))
' "$ACTIVE_THEME"; then
        READY=true
        break
      fi
      sleep 0.1
    done
    if [[ "$READY" != true ]]; then
      echo "Alacritty did not load $ACTIVE_THEME; tmux colors were not refreshed." >&2
      return 1
    fi
  done
  if [[ "$SOCKET_FOUND" != true ]]; then
    echo "No Alacritty IPC socket found; tmux colors were not refreshed." >&2
    return 1
  fi

  # Write to the outer terminal so tmux receives OSC 10/11 replies and updates
  # its cached defaults. A query inside a pane only returns the cached colors.
  while read -r CLIENT_TERM CLIENT_TTY; do
    [[ "$CLIENT_TERM" == alacritty && -c "$CLIENT_TTY" && -w "$CLIENT_TTY" ]] || continue
    printf '\033]10;?\007\033]11;?\007' > "$CLIENT_TTY"
  done <<< "$CLIENTS"
}

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
# invocations need only a tmux color refresh: skip the apply steps when both the
# appearance and theme file already match, so borders isn't restarted for no reason.
# An explicit light/dark argument always applies (it doubles as a re-kick).
if [ -z "${1:-}" ] && cmp -s "$THEME_DIR/$MODE.toml" "$ACTIVE_THEME" 2>/dev/null; then
  STYLE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light)
  if { [ "$MODE" = dark ] && [ "$STYLE" = Dark ]; } ||
     { [ "$MODE" = light ] && [ "$STYLE" = Light ]; }; then
    refresh_tmux_colors
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
refresh_tmux_colors

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
