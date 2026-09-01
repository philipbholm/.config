#!/usr/bin/env bash
# macOS notifications for Claude Code — on/off switch + hook handler.
#
# Usage:
#   claude-notify on|off|toggle|status   manage notifications
#   claude-notify stop|notification      hook mode (reads hook JSON on stdin)
#
# Wired into Claude Code via the Stop and Notification hooks in
# claude/settings.json. State lives in a machine-local file (not version
# controlled); a missing state file counts as enabled. Posts via
# terminal-notifier (Brewfile) with osascript as a floor; clicking the
# banner focuses Alacritty.

set -u

STATE_FILE="${CLAUDE_NOTIFY_STATE:-$HOME/.claude/notify.state}"
LOG_FILE="${CLAUDE_NOTIFY_LOG:-$HOME/.claude/notify.log}"

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
  if is_enabled; then echo "Claude notifications: ON"; else echo "Claude notifications: OFF"; fi
}

send() {
  # $1 = message, $2 = sound, $3 = group key (coalesces banners per project).
  local message="$1" sound="$2" group="$3"
  if command -v terminal-notifier >/dev/null 2>&1; then
    terminal-notifier -title "Claude Code" -message "$message" -sound "$sound" \
      -group "claude-$group" -activate org.alacritty >/dev/null 2>>"$LOG_FILE" \
      || log "send failed: $message"
  else
    local esc
    esc=$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g')
    osascript -e "display notification \"$esc\" with title \"Claude Code\" sound name \"$sound\"" \
      >/dev/null 2>>"$LOG_FILE" || log "send failed: $message"
  fi
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
    # Don't announce "done" while background subagents/teammates/shells are
    # still in flight — the session isn't finished, it wakes again when they
    # complete (and fires Stop with an empty list then). background_tasks lists
    # in-flight (running/pending) work; absent/empty => genuinely at rest.
    bg=$(printf '%s' "$payload" | jq -r '(.background_tasks // []) | length' 2>/dev/null)
    case "$bg" in ''|*[!0-9]*) bg=0 ;; esac
    [ "$bg" -gt 0 ] && { log "skip stop: $bg background task(s) in flight"; exit 0; }
    cwd=$(printf '%s' "$payload" | jq -r '.cwd // "unknown"' 2>/dev/null)
    send "done — $(basename "$cwd")" Hero "$(basename "$cwd")"
    ;;
  notification)
    is_enabled || exit 0
    payload=$(cat)
    tp=$(printf '%s' "$payload" | jq -r '.transcript_path // ""' 2>/dev/null)
    case "$tp" in */subagents/*) exit 0 ;; esac
    ntype=$(printf '%s' "$payload" | jq -r '.notification_type // "?"' 2>/dev/null)
    # idle_prompt fires ~60s after the turn ends, with no awareness of running
    # background subagents/teammates — so it false-alarms "idle" while Claude is
    # actually waiting on them. It's also redundant with the Stop "done"
    # notification, so drop it. permission_prompt/elicitation/etc. still notify.
    [ "$ntype" = "idle_prompt" ] && { log "skip notification: idle_prompt"; exit 0; }
    cwd=$(printf '%s' "$payload" | jq -r '.cwd // "unknown"' 2>/dev/null)
    # No leading "[" — terminal-notifier drops a -message that starts with it.
    send "$ntype — $(basename "$cwd")" Sosumi "$(basename "$cwd")"
    ;;
  *)
    echo "usage: claude-notify on|off|toggle|status" >&2
    exit 2
    ;;
esac
