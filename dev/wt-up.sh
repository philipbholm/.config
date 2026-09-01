#!/bin/bash
set -euo pipefail

. "$HOME/.config/dev/lib/workspace.sh"

### wt-up.sh — Create a harness-agnostic worktree
###
### Usage:
###   wt-up <name> <branch> [start-point]
###
### An existing local branch is checked out as-is. A missing branch is created
### from start-point, or from the current checkout's HEAD when omitted.

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: wt-up <name> <branch> [start-point]" >&2
  exit 1
fi

name=$1
branch=$2
start_point=${3:-}

if [[ ! "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
  echo "Error: name must contain only letters, numbers, dots, underscores, and hyphens." >&2
  exit 1
fi

current_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Error: not inside a git repository" >&2
  exit 1
}
common_dir=$(dev_git_common_dir_abs "$current_root") || {
  echo "Error: could not resolve the git common dir" >&2
  exit 1
}
main_repo=$(dirname "$common_dir")
worktree_base=$(dev_worktree_base_for_repo "$main_repo")
worktree_path="$worktree_base/$name"

if [[ -e "$worktree_path" ]]; then
  echo "Error: $worktree_path already exists." >&2
  exit 1
fi

mkdir -p "$worktree_base"

if git -C "$main_repo" show-ref --verify --quiet "refs/heads/$branch"; then
  if [[ -n "$start_point" ]]; then
    echo "Error: branch '$branch' already exists; do not pass a start point." >&2
    exit 1
  fi
  git -C "$main_repo" worktree add "$worktree_path" "$branch"
elif git -C "$main_repo" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  if [[ -n "$start_point" ]]; then
    echo "Error: origin/$branch already exists; do not pass a start point." >&2
    exit 1
  fi
  git -C "$main_repo" worktree add --track -b "$branch" "$worktree_path" "origin/$branch"
else
  git -C "$main_repo" worktree add -b "$branch" "$worktree_path" "${start_point:-HEAD}"
fi

if [[ "$main_repo" == "$HOME/work/ledidi-monorepo" ]]; then
  "$HOME/.config/dev/sync-context.sh" ||
    echo "Warning: context sync failed; AGENTS.md and CLAUDE.local.md may be missing." >&2
fi

echo
echo "Created $worktree_path"
echo "Continue in that directory, then run setup-stack."
