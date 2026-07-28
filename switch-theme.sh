#!/bin/bash

THEME_DIR="$HOME/.config/alacritty/themes"
ACTIVE_THEME="$HOME/.config/alacritty/active_theme.toml"

# Determine theme based on time in Europe/Oslo (dark 18:00–07:00)
HOUR=$(TZ=Europe/Oslo date +%-H)
if [ "$HOUR" -ge 18 ] || [ "$HOUR" -lt 7 ]; then
    MODE="Dark"
else
    MODE="Light"
fi

# Set macOS appearance
if [ "$MODE" = "Dark" ]; then
    osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
    ln -sf "$THEME_DIR/dark.toml" "$ACTIVE_THEME"
else
    osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to false'
    ln -sf "$THEME_DIR/light.toml" "$ACTIVE_THEME"
fi

# Reload borders with the current bordersrc config.
#
# Do NOT call bordersrc directly: `borders` is a long-running daemon that runs
# in the foreground (which is what com.philip.borders expects of it), so
# invoking it here never returns — it hangs the caller and leaks a second
# daemon. Restarting the launch agent applies the config and returns at once.
if ! launchctl kickstart -k "gui/$(id -u)/com.philip.borders" 2>/dev/null; then
    # Agent not loaded (e.g. first install before launch agents are set up).
    ~/.config/borders/bordersrc &
fi
