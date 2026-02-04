#!/bin/bash

# Read JSON from stdin
input=$(cat)

# Extract notification_type using grep/sed
event=$(echo "$input" | grep -o '"notification_type":"[^"]*"' | sed 's/"notification_type":"//;s/"//')

case "$event" in
  "permission_prompt")
    osascript -e 'tell application "Finder" to display notification "Claude needs your permission to proceed" with title "Claude Code - Permission Required"'
    ;;
  "idle_prompt")
    osascript -e 'tell application "Finder" to display notification "Claude is waiting for your input" with title "Claude Code - Ready"'
    ;;
esac
