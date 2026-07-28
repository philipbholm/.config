#!/bin/bash
input=$(cat)

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
used_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
# Drop trailing context-window suffix, e.g. "Opus 4.8 (1M context)" -> "Opus 4.8"
model=$(echo "$model" | sed -E 's/ *\([0-9]+[MK]? context\)//')
# Live session effort, not the configured default — only present on models that support it
effort=$(echo "$input" | jq -r '.effort.level // empty')

# Current dir (basename) + git branch from cwd
dir=""
branch=""
if [ -n "$cwd" ]; then
  dir=$(basename "$cwd")
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Context usage: percentage + token count (no progress bar)
bar=""
if [ -n "$used_pct" ]; then
  pct_int=$(printf '%.0f' "$used_pct")
  bar="${pct_int}%"
  if [ -n "$used_tokens" ]; then
    tokens_fmt=$(echo "$used_tokens" | sed -e :a -e 's/\(.*[0-9]\)\([0-9]\{3\}\)/\1 \2/;ta')
    bar="$bar ($tokens_fmt)"
  fi
fi

# Per-turn delta tracking
state_dir="/tmp/claude-statusline"
mkdir -p "$state_dir"
prev_cost=0
if [ -n "$session_id" ]; then
  state_file="$state_dir/$session_id"
  if [ -f "$state_file" ]; then
    prev_cost=$(cat "$state_file")
  fi
  echo "${cost_usd:-0}" > "$state_file"
fi

# Cost in NOK (USD * 10) with per-turn delta
nok=""
if [ -n "$cost_usd" ]; then
  total_nok=$(printf '%.2f' "$(echo "$cost_usd * 10" | bc)")
  delta_nok=$(printf '%.2f' "$(echo "($cost_usd - $prev_cost) * 10" | bc)")
  nok="NOK $total_nok (+$delta_nok)"
fi

# Model + effort label
model_effort=""
if [ -n "$model" ] && [ -n "$effort" ]; then
  model_effort="$model ($effort)"
elif [ -n "$model" ]; then
  model_effort="$model"
fi

# Build output
parts=()
[ -n "$bar" ] && parts+=("$bar")
dir_branch=""
[ -n "$dir" ] && dir_branch="$dir"
if [ -n "$branch" ] && [ "$branch" != "$dir" ]; then
  dir_branch="${dir_branch:+$dir_branch · }$branch"
fi
[ -n "$dir_branch" ] && parts+=("$dir_branch")
[ -n "$model_effort" ] && parts+=("$model_effort")
[ -n "$nok" ] && parts+=("$nok")

first=true
for p in "${parts[@]}"; do
  if $first; then first=false; else printf ' | '; fi
  printf '%s' "$p"
done
