#!/bin/bash
set -euo pipefail

script_path=${BASH_SOURCE[0]}
while [[ -L "$script_path" ]]; do
  script_parent=$(cd "$(dirname "$script_path")" && pwd)
  script_path=$(readlink "$script_path")
  [[ "$script_path" == /* ]] || script_path="$script_parent/$script_path"
done
SCRIPT_DIR=$(cd "$(dirname "$script_path")" && pwd)
. "$SCRIPT_DIR/lib/cli.sh"
. "$SCRIPT_DIR/lib/checkout.sh"

if [[ $# -eq 0 || "${1:-}" == --help || "${1:-}" == -h ]]; then
  dev_help story
  exit 0
fi
[[ $# -eq 1 ]] || dev_cli_error "use story <slot>"

slot=$1
[[ "$slot" =~ ^[0-9]$ ]] || dev_cli_error "slot must be 0-9"

main_repo=${DEV_MAIN_REPO:-$HOME/work/ledidi-monorepo}
[[ -d "$main_repo/.git" ]] || dev_cli_error "Ledidi main checkout not found: $main_repo"

checkout=""
if [[ "$slot" == 0 ]]; then
  checkout=$main_repo
else
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] || continue
    candidate_slot=$(dev_slot_for_repo "$candidate")
    if [[ "$candidate_slot" == "$slot" ]]; then
      if [[ -n "$checkout" ]]; then
        dev_cli_error "slot $slot is assigned to more than one worktree"
      fi
      checkout=$candidate
    fi
  done < <(git -C "$main_repo" worktree list --porcelain | sed -n 's/^worktree //p')
fi

[[ -n "$checkout" ]] || dev_cli_error "no worktree is assigned to slot $slot"

workspace="$checkout/apps/registries-frontend"
[[ -f "$workspace/package.json" ]] || dev_cli_error "registries frontend not found in $checkout"

if [[ ! -d "$workspace/node_modules" ]]; then
  echo "Preparing apps/registries-frontend in $checkout"
  (cd "$checkout" && bash "$SCRIPT_DIR/workspace-prepare.sh" apps/registries-frontend)
fi

port=$(( 6009 + slot ))
while lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; do
  port=$(( port + 1 ))
  [[ "$port" -le 65535 ]] || dev_cli_error "no free Storybook port is available"
done

echo "Storybook: $checkout (slot $slot)"
echo "URL: http://localhost:$port"
echo "Press Ctrl-C to stop Storybook."
cd "$workspace"
export STORYBOOK_REGISTRIES_PORT=$port
exec npm run storybook
