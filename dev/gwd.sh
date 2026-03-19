#!/bin/bash
set -euo pipefail

### gwd.sh — Remove git worktree and clean up dev stack
### Nukes the dev stack (if running), resets the worktree, and removes it.
###
### Usage:
###   gwd <branch-name>
###
### Examples:
###   gwd feat/my-feature        Nuke stack, reset, and remove worktree

DEV_CMD="/Users/philip/.config/dev/dev.sh"
WORKTREE_BASE="/Users/philip/work/worktrees"

if [[ -z "${1:-}" ]]; then
  echo "Usage: gwd <branch-name>"
  exit 1
fi

branch="$1"
worktree_path="$WORKTREE_BASE/$branch"
project_name="$branch"

[[ ! -d "$worktree_path" ]] && { echo "Worktree not found: $worktree_path"; exit 1; }

slot_file="${DEV_STACKS_DIR:-$HOME/work/.dev-stacks}/$project_name/worktree-slot"
if [ -f "$slot_file" ]; then
  (cd "$worktree_path" && "$DEV_CMD" nuke)
  containers=$(docker ps -q --filter "label=com.docker.compose.project=$project_name" 2>/dev/null)
  [ -n "$containers" ] && docker wait "$containers" >/dev/null 2>&1
fi

git -C "$worktree_path" checkout -- . && git -C "$worktree_path" clean -fd && git worktree remove "$worktree_path"
