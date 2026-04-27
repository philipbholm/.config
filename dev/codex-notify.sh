#!/usr/bin/env bash
# Codex notify hook - posts a Telegram message when Codex is idle.

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

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  secrets_file="$HOME/.config/zsh/.zsh_secrets"
  if [ -r "$secrets_file" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$secrets_file" >/dev/null 2>&1 || true
    set +a
  fi
fi

if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
  log "missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID"
  exit 0
fi

if ! curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
  --data-urlencode "text=Codex idle - $(basename "$cwd")" \
  >/dev/null 2>>"$log_file"; then
  log "telegram send failed"
fi
