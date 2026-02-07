#!/bin/bash

# Read JSON from stdin
input=$(cat)

# Extract notification_type using grep/sed
event=$(echo "$input" | grep -o '"notification_type":"[^"]*"' | sed 's/"notification_type":"//;s/"//')

# Determine aerospace workspace from project folder name in window title
project=$(basename "$PWD")
workspace=$(aerospace list-windows --all --format '%{workspace}|%{window-title}' 2>/dev/null | grep "— ${project}" | head -1 | cut -d'|' -f1)

# Get tmux window index
tmux_index=$(tmux display-message -t "$TMUX_PANE" -p '#{window_index}' 2>/dev/null)

# Build context tag, e.g. [W6-1]
context=""
[ -n "$workspace" ] && context="$workspace"
[ -n "$tmux_index" ] && context="${context:+$context-}$tmux_index"
ctx_tag="${context:+ [$context]}"

case "$event" in
  "permission_prompt")
    alerter -message "Claude needs your permission to proceed" -title "Claude Code${ctx_tag} - Permission Required" -sound "Glass" -timeout 10 > /dev/null 2>&1 &
    ;;
  "idle_prompt")
    alerter -message "Claude is waiting for your input" -title "Claude Code${ctx_tag} - Ready" -sound "Glass" -timeout 10 > /dev/null 2>&1 &
    ;;
esac
