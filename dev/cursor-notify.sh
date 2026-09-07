#!/usr/bin/env bash
# Cursor agent CLI notify hook — posts a macOS notification when a turn ends.
#
# Wired via the `stop` hook in ~/.cursor/hooks.json (linked from
# cursor-agent/hooks.json). Cursor sends the hook JSON on stdin. `stop` can fire
# once per model turn rather than only at final rest, so this only notifies on a
# completed turn to cut repeats. Posts via terminal-notifier (osascript floor);
# clicking the banner focuses Alacritty. The Claude and Codex equivalents are
# dev/claude-notify.sh and dev/codex-notify.sh.
set -u

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: cursor-notify.sh (hook JSON on stdin)"
  echo "Posts a macOS notification for a completed Cursor turn."
  exit 0
fi

log_file="${CURSOR_NOTIFY_LOG:-$HOME/.cursor/notify.log}"
log() {
  mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
  printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$log_file" 2>/dev/null || true
}

payload=$(cat)
message="Cursor idle"
if command -v jq >/dev/null 2>&1 && [ -n "$payload" ]; then
  status=$(printf '%s' "$payload" | jq -r '.status // ""' 2>/dev/null)
  # Only the final, successful end of the loop — not every intermediate turn.
  [ -n "$status" ] && [ "$status" != "completed" ] && exit 0
  dir=$(printf '%s' "$payload" | jq -r '(.cwd // .workspace_roots[0]? // "")' 2>/dev/null)
  [ -n "$dir" ] && message="idle - $(basename "$dir")"
fi

if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "Cursor" -message "$message" -sound Hero \
    -group "cursor-$message" -activate org.alacritty >/dev/null 2>>"$log_file" \
    || log "send failed: $message"
else
  esc=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')
  osascript -e "display notification \"$esc\" with title \"Cursor\" sound name \"Hero\"" \
    >/dev/null 2>>"$log_file" || log "send failed: $message"
fi
