#!/bin/bash

# Read JSON from stdin
input=$(cat)

# Extract notification_type using grep/sed
event=$(echo "$input" | grep -o '"notification_type":"[^"]*"' | sed 's/"notification_type":"//;s/"//')

case "$event" in
  "permission_prompt")
    osascript -e 'display notification "Claude needs your permission to proceed" with title "Claude Code - Permission Required" sound name "Glass"'
    ;;
  "idle_prompt")
    osascript -e 'display notification "Claude is waiting for your input" with title "Claude Code - Ready" sound name "Glass"'
    ;;
esac
