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

terminal_agent_running() {
  local PROCESSES
  if ! PROCESSES=$(ps -U "$(id -u)" -o tty=,comm=); then
    echo "Could not inspect terminal agents; keeping the current Alacritty theme." >&2
    return 0
  fi

  # A terminal is required so desktop app servers do not hold the theme forever.
  # Cursor's launchers use exec -a; some versions expose the bundled Node path.
  awk '
    $1 != "??" && $1 != "?" {
      sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+/, "")
      if ($0 ~ /(^|\/)(codex|claude|agent|cursor-agent)$/ ||
          $0 ~ /\/cursor-agent\/versions\/[^\/]+\/node$/)
        found = 1
    }
    END { exit !found }
  ' <<< "$PROCESSES"
}

main() {
  local MODE="${1:-}" HOUR DARK STYLE
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
      return 1
      ;;
  esac

  STYLE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light)
  if [ -n "${1:-}" ] ||
     { [ "$MODE" = dark ] && [ "$STYLE" != Dark ]; } ||
     { [ "$MODE" = light ] && [ "$STYLE" != Light ]; }; then
    # The local clock owns the schedule, including after timezone changes.
    defaults write -g AppleInterfaceStyleSwitchesAutomatically -bool false
    osascript -e "tell application \"System Events\" to tell appearance preferences to set dark mode to $DARK"

    # borders is a foreground daemon managed by launchd. Restart its agent to
    # apply the appearance without leaving another daemon running.
    if ! launchctl kickstart -k "gui/$(id -u)/com.philip.borders" 2>/dev/null; then
      "$HOME/.config/borders/bordersrc" "$MODE" &
    fi
  fi

  if cmp -s "$THEME_DIR/$MODE.toml" "$ACTIVE_THEME"; then
    # Explicit calls also repair tmux's cached colors when the theme matches.
    if [ -n "${1:-}" ]; then
      refresh_tmux_colors
    fi
    return 0
  fi

  # Terminal agents can cache colors for their process lifetime. Preserve the
  # palette until all local terminal agents exit; launchd retries every minute.
  if [ -e "$ACTIVE_THEME" ] && terminal_agent_running; then
    return 0
  fi

  # Alacritty watches the resolved import path, so replace the file rather than
  # swapping a symlink. Remove an existing symlink without writing through it.
  if [ -e "$ACTIVE_THEME" ] || [ -L "$ACTIVE_THEME" ]; then
    rm "$ACTIVE_THEME"
  fi
  cp "$THEME_DIR/$MODE.toml" "$ACTIVE_THEME"
  touch "$HOME/.config/alacritty/alacritty.toml"
  refresh_tmux_colors
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
