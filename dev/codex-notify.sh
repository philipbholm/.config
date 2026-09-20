#!/usr/bin/env bash

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Usage: codex-notify.sh '<hook JSON>'"
  echo "Posts a macOS notification for a completed Codex turn."
  exit 0
fi

payload="${1:-}"
cwd="${PWD:-unknown}"
log_file="${CODEX_NOTIFY_LOG:-$HOME/.codex/notify.log}"

log() {
  mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
  printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$log_file" 2>/dev/null || true
}

if [ -n "$payload" ] && command -v jq >/dev/null 2>&1; then
  type=$(printf '%s' "$payload" | jq -r '.type // ""' 2>/dev/null)
  if [ -n "$type" ] && [ "$type" != "agent-turn-complete" ] && [ "$type" != "turn-complete" ]; then
    exit 0
  fi

  payload_cwd=$(printf '%s' "$payload" | jq -r '.cwd // ""' 2>/dev/null)
  [ -n "$payload_cwd" ] && cwd="$payload_cwd"

  # Child agents inherit notify, but its payload omits the session source.
  # Read only the metadata line to avoid announcing their completion as idle.
  thread_id=$(printf '%s' "$payload" | jq -r '."thread-id" // ""' 2>/dev/null)
  if [[ "$thread_id" =~ ^[[:xdigit:]]{8}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{4}-[[:xdigit:]]{12}$ ]]; then
    session_file=$(find "${CODEX_HOME:-$HOME/.codex}/sessions" -type f \
      -name "rollout-*-$thread_id.jsonl" -print -quit 2>/dev/null)
    if [ -n "$session_file" ] && head -n 1 "$session_file" | jq -e --arg id "$thread_id" '
      .type == "session_meta" and .payload.id == $id and
      (.payload.source | if type == "object" then has("subagent") else false end)
    ' >/dev/null 2>&1; then
      exit 0
    fi
  fi
fi

message="idle - $(basename "$cwd")"
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier -title "Codex" -message "$message" -sound Hero \
    -group "codex-$(basename "$cwd")" -activate org.alacritty \
    >/dev/null 2>>"$log_file" || log "send failed: $message"
else
  esc=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')
  osascript -e "display notification \"$esc\" with title \"Codex\" sound name \"Hero\"" \
    >/dev/null 2>>"$log_file" || log "send failed: $message"
fi
