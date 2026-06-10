#!/usr/bin/env bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
MAX=$(echo "$input" | jq -r 'if .model.max_mode then " MAX" else "" end')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
USED=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')

BRANCH=""
git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1 && \
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)

format_tokens() {
  local n=$1
  local result=""
  while [ ${#n} -gt 3 ]; do
    result=" ${n: -3}${result}"
    n="${n:0:${#n}-3}"
  done
  echo "${n}${result}"
}

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

CTX="${BAR} ${PCT}%"
[ -n "$USED" ] && CTX="${CTX} ($(format_tokens "$USED"))"

DIRNAME="${DIR##*/}"
LOCATION="$DIRNAME"
[ -n "$BRANCH" ] && [ "$BRANCH" != "$DIRNAME" ] && LOCATION="${LOCATION} · ${BRANCH}"

MODEL_LINE="\033[90m${MODEL}\033[0m"
[ -n "$MAX" ] && MODEL_LINE="${MODEL_LINE}\033[33m${MAX}\033[0m"

LINE="\033[90m${CTX}\033[0m | \033[90m${LOCATION}\033[0m | ${MODEL_LINE}"

printf '%b' "$LINE"
