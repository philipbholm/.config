#!/usr/bin/env zsh
set -euo pipefail

# Parse flags
validation_mode=false
remaining_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --validation|-v) validation_mode=true; shift ;;
    *) remaining_args+=("$1"); shift ;;
  esac
done

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Error: Not inside a git repository"
  exit 1
}

# Determine ports from worktree slot
project_name="$(basename "$monorepo_root")"
worktree_slot_file="${DEV_STACKS_DIR:-$HOME/work/tmp/dev-stacks}/$project_name/worktree-slot"
if [[ -f "$worktree_slot_file" ]]; then
  slot=$(cat "$worktree_slot_file")
  offset=$((slot * 100))
  frontend_port=$((3001 + offset))
  api_port=$((4000 + offset))
else
  frontend_port=3001
  api_port=4000
fi

export FRONTEND_BASE_URL="http://localhost:$frontend_port"
export E2E_API_URL="http://localhost:$api_port"
export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--no-deprecation"

echo "Running e2e tests against $FRONTEND_BASE_URL (API: $E2E_API_URL)..."

cd "$monorepo_root/apps/main-frontend"

if [[ "$validation_mode" == true ]]; then
  npx playwright test --config=playwright.validation.config.ts "src/app/\[lang\]/registries" "${remaining_args[@]}"
else
  npx playwright test "src/app/\[lang\]/registries" "${remaining_args[@]}"
fi
