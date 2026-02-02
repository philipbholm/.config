#!/bin/bash

THEME_DIR="$HOME/.config/alacritty/themes"
ACTIVE_THEME="$HOME/.config/alacritty/active_theme.toml"

CURRENT_MODE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")

if [ "$CURRENT_MODE" = "Dark" ]; then
    ln -sf "$THEME_DIR/dark.toml" "$ACTIVE_THEME"
else
    ln -sf "$THEME_DIR/light.toml" "$ACTIVE_THEME"
fi

touch "$ACTIVE_THEME"

# Restart borders to update window border colors
brew services restart borders
