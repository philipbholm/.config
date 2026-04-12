#!/usr/bin/env bash

set -euo pipefail

socket_name=$(tmux display-message -p '#{socket_path}' 2>/dev/null | tr '/:' '__')
pidfile="/tmp/tmux-ai-attention-${socket_name}.pid"

codex_needs_input() {
  local pane_id="$1"
  local output

  output=$(tmux capture-pane -p -J -t "$pane_id" -S -80 2>/dev/null || true)

  [[ -n "$output" ]] || return 1

  grep -Eqi \
    'Type instructions and press Enter|RequestPermissions|AskForApproval|approval_policy|approvalId|Press Enter to send' \
    <<<"$output"
}

update_once() {
  local window_id

  while IFS= read -r window_id; do
    local attention="0"
    local claude_attention

    claude_attention=$(tmux show-options -wqv -t "$window_id" @ai_attention_claude 2>/dev/null || true)
    if [[ "$claude_attention" == "1" ]]; then
      attention="1"
    fi

    if [[ "$attention" == "0" ]]; then
      while IFS=$'\t' read -r pane_id pane_title pane_command; do
        if [[ "$pane_title" == "ai:codex" ]] || [[ "$pane_command" == "codex" ]]; then
          if codex_needs_input "$pane_id"; then
            attention="1"
            break
          fi
        fi
      done < <(tmux list-panes -t "$window_id" -F $'#{pane_id}\t#{pane_title}\t#{pane_current_command}')
    fi

    tmux set-option -wq -t "$window_id" @ai_attention "$attention"
  done < <(tmux list-windows -a -F '#{window_id}')
}

if [[ "${1:-}" == "--once" ]]; then
  update_once
  exit 0
fi

if [[ -f "$pidfile" ]]; then
  existing_pid=$(cat "$pidfile" 2>/dev/null || true)
  if [[ -n "${existing_pid:-}" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    exit 0
  fi
fi

echo "$$" >"$pidfile"
trap 'rm -f "$pidfile"' EXIT

while true; do
  update_once
  sleep 2
done
