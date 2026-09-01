#!/usr/bin/env bash
# Codex notify hook - posts a macOS notification when Codex is idle.

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
