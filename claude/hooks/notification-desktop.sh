#!/bin/bash

# Read JSON from stdin
input=$(cat)

# Extract notification_type using grep/sed
event=$(echo "$input" | grep -o '"notification_type":"[^"]*"' | sed 's/"notification_type":"//;s/"//')

# Determine aerospace workspace from project folder name in window title
project=$(basename "$PWD")
workspace=$(aerospace list-windows --all --format '%{workspace}|%{window-title}' 2>/dev/null | grep "— ${project}" | head -1 | cut -d'|' -f1)
ws_tag="${workspace:+ [$workspace]}"

case "$event" in
  "permission_prompt")
    osascript -e "display notification \"Claude needs your permission to proceed\" with title \"Claude Code${ws_tag} - Permission Required\" sound name \"Glass\""
    ;;
  "idle_prompt")
    osascript -e "display notification \"Claude is waiting for your input\" with title \"Claude Code${ws_tag} - Ready\" sound name \"Glass\""
    ;;
esac
