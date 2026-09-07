#!/usr/bin/env bash
input=$(cat)

eval "$(printf '%s' "$input" | jq -r '
  @sh "MODEL=\(.model.display_name // "")",
  @sh "PARAMS=\(.model.param_summary // "")",
  @sh "MAX_MODE=\(if .model.max_mode == true then "1" else "0" end)",
  @sh "PCT=\((.context_window.used_percentage // 0) | floor)",
  @sh "USED=\(
    if .context_window.total_input_tokens == null
    then ""
    else (.context_window.total_input_tokens | tostring)
    end
  )",
  @sh "DIR=\(.workspace.current_dir // .cwd // "")",
  @sh "WT=\(
    .worktree.name // (
      (.workspace.current_dir // .cwd // "")
      | split("/.worktrees/")
      | if length > 1 then (.[1] | split("/")[0]) else "" end
    )
  )"
')"

BRANCH=""
if [ -n "$DIR" ] && git -C "$DIR" rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
fi

format_tokens() {
  local n=$1
  local result=""
  while [ ${#n} -gt 3 ]; do
    result=" ${n: -3}${result}"
    n="${n:0:${#n}-3}"
  done
  echo "${n}${result}"
}

PCT=${PCT:-0}
BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
[ "$FILLED" -gt "$BAR_WIDTH" ] && FILLED=$BAR_WIDTH
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

if [ "$PCT" -ge 80 ]; then
  CTX_COLOR="31"
elif [ "$PCT" -ge 50 ]; then
  CTX_COLOR="33"
else
  CTX_COLOR="32"
fi

CTX="${BAR} ${PCT}%"
[ -n "$USED" ] && CTX="${CTX} ($(format_tokens "$USED"))"

if [ -n "$WT" ]; then
  LOCATION="$WT"
elif [ -n "$DIR" ]; then
  LOCATION="${DIR##*/}"
else
  LOCATION=""
fi
if [ -n "$BRANCH" ] && [ "$BRANCH" != "$LOCATION" ]; then
  LOCATION="${LOCATION} · ${BRANCH}"
fi

MODEL_LINE="${MODEL}"
[ -n "$PARAMS" ] && MODEL_LINE="${MODEL_LINE} ${PARAMS}"

printf '\033[%sm%s\033[0m' "$CTX_COLOR" "$CTX"
[ -n "$LOCATION" ] && printf ' \033[90m|\033[0m \033[90m%s\033[0m' "$LOCATION"
[ -n "$MODEL_LINE" ] && printf ' \033[90m|\033[0m \033[90m%s\033[0m' "$MODEL_LINE"
[ "$MAX_MODE" = "1" ] && printf '\033[33m MAX\033[0m'
printf '\n'
