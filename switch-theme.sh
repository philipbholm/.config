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

# Update borders colors by re-executing bordersrc (supports live reconfiguration)
~/.config/borders/bordersrc
