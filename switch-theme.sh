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

# Update borders colors by re-executing bordersrc (supports live reconfiguration)
~/.config/borders/bordersrc

# Update all running nvim instances
if [ "$CURRENT_MODE" = "Dark" ]; then
    BG="dark"
else
    BG="light"
fi
for sock in /var/folders/*/*/T/nvim.*/*/nvim.*.0; do
    [ -S "$sock" ] && nvim --server "$sock" --remote-send "<Cmd>set background=$BG<CR>" 2>/dev/null &
done
wait
