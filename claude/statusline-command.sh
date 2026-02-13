#!/bin/bash
input=$(cat)

used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
session_id=$(echo "$input" | jq -r '.session_id // empty')
cwd=$(echo "$input" | jq -r '.cwd // empty')

# Git branch from cwd
branch=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Context bar
bar=""
if [ -n "$used_pct" ]; then
  pct_int=$(printf '%.0f' "$used_pct")
  filled=$((pct_int / 10))
  empty=$((10 - filled))
  bar=$(printf '█%.0s' $(seq 1 $filled 2>/dev/null))$(printf '░%.0s' $(seq 1 $empty 2>/dev/null))
  bar="$bar ${pct_int}%"
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

# Build output
parts=()
[ -n "$bar" ] && parts+=("$bar")
[ -n "$branch" ] && parts+=("$branch")
[ -n "$nok" ] && parts+=("$nok")

first=true
for p in "${parts[@]}"; do
  if $first; then first=false; else printf ' | '; fi
  printf '%s' "$p"
done
