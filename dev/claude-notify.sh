#!/usr/bin/env bash
# Telegram notifications for Claude Code — on/off switch + hook handler.
#
# Usage:
#   claude-notify on|off|toggle|status   manage notifications
#   claude-notify stop|notification      hook mode (reads hook JSON on stdin)
#
# Wired into Claude Code via the Stop and Notification hooks in
# claude/settings.json. State lives in a machine-local file (not version
# controlled); a missing state file counts as enabled. Sends are best-effort
# and silently no-op when the Telegram secrets are absent.

set -u

STATE_FILE="${CLAUDE_NOTIFY_STATE:-$HOME/.claude/telegram-notify.state}"
LOG_FILE="${CLAUDE_NOTIFY_LOG:-$HOME/.claude/telegram-notify.log}"

log() {
  printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOG_FILE" 2>/dev/null || true
}

is_enabled() {
  # Missing/unwritten state file => enabled.
  [ "$(cat "$STATE_FILE" 2>/dev/null)" != "off" ]
}

set_state() {
  mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
  printf '%s\n' "$1" >"$STATE_FILE"
}

report() {
  if is_enabled; then echo "Claude Telegram notifications: ON"; else echo "Claude Telegram notifications: OFF"; fi
}

send() {
  # $1 = message text. Loads secrets lazily so it works even when the hook
  # runs without the interactive shell's environment.
  if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    local secrets_file="$HOME/.config/zsh/.zsh_secrets"
    if [ -r "$secrets_file" ]; then
      set -a
      # shellcheck disable=SC1090
      . "$secrets_file" >/dev/null 2>&1 || true
      set +a
    fi
  fi

  if [ -z "${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "${TELEGRAM_CHAT_ID:-}" ]; then
    log "skip: missing TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID"
    return 0
  fi

  curl -fsS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=$1" >/dev/null 2>>"$LOG_FILE" || log "send failed: $1"
}

case "${1:-status}" in
  on)
    set_state on
    report
    ;;
  off)
    set_state off
    report
    ;;
  toggle)
    if is_enabled; then set_state off; else set_state on; fi
    report
    ;;
  status)
    report
    ;;
  stop)
    is_enabled || exit 0
    payload=$(cat)
    tp=$(printf '%s' "$payload" | jq -r '.transcript_path // ""' 2>/dev/null)
    case "$tp" in */subagents/*) exit 0 ;; esac
    cwd=$(printf '%s' "$payload" | jq -r '.cwd // "unknown"' 2>/dev/null)
    send "Claude Code done — $(basename "$cwd")"
    ;;
  notification)
    is_enabled || exit 0
    payload=$(cat)
    ntype=$(printf '%s' "$payload" | jq -r '.notification_type // "?"' 2>/dev/null)
    cwd=$(printf '%s' "$payload" | jq -r '.cwd // "unknown"' 2>/dev/null)
    send "Claude Code [$ntype] — $(basename "$cwd")"
    ;;
  *)
    echo "usage: claude-notify on|off|toggle|status" >&2
    exit 2
    ;;
esac
