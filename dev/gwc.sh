#!/bin/bash
set -euo pipefail

. "$HOME/.config/dev/lib/workspace.sh"

### gwc.sh — Create git worktree with dev environment
### Sets up a new worktree, copies context files, and runs setup-stack.sh.
###
### Usage:
###   gwc [-n|--no-setup] <branch-name>
###
### Options:
###   -n, --no-setup    Skip running setup-stack.sh (just create worktree)
###
### Examples:
###   gwc feat/my-feature        Create worktree from origin/HEAD and setup stack
###   gwc -n fix/quick-patch     Create worktree without running setup

WORKTREE_BASE="$(dev_worktree_base)"
CONTEXT_SRC="/Users/philip/.config/dev/context/ledidi-monorepo"
SETUP_CMD="/Users/philip/.config/dev/setup-stack.sh"

default_base_ref() {
  if [[ -n "${GWC_BASE_REF:-}" ]]; then
    printf '%s\n' "$GWC_BASE_REF"
    return 0
  fi

  local origin_head
  origin_head=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null || true)
  if [[ -n "$origin_head" ]]; then
    printf '%s\n' "${origin_head#refs/remotes/}"
    return 0
  fi

  if git show-ref --verify --quiet refs/remotes/origin/main; then
    printf '%s\n' "origin/main"
    return 0
  fi

  if git show-ref --verify --quiet refs/remotes/origin/master; then
    printf '%s\n' "origin/master"
    return 0
  fi

  echo "Error: Could not determine a default base branch from origin." >&2
  echo "Set GWC_BASE_REF to an explicit ref, for example: export GWC_BASE_REF=origin/main" >&2
  exit 1
}

no_setup=false
while [[ "${1:-}" == -* ]]; do
  case "$1" in
    -n|--no-setup) no_setup=true; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

if [[ -z "${1:-}" ]]; then
  echo "Usage: gwc [-n|--no-setup] <branch-name>"
  exit 1
fi

branch="$1"
worktree_path="$WORKTREE_BASE/$branch"

# Must be in a git repo
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "Error: Not inside a git repository"; exit 1; }

git fetch origin
base_ref=$(default_base_ref)

if git show-ref --verify --quiet "refs/heads/$branch"; then
  git worktree add "$worktree_path" "$branch" || exit 1
elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  git worktree add "$worktree_path" "$branch" || exit 1
else
  git worktree add -b "$branch" "$worktree_path" "$base_ref" || exit 1
fi

# Copy context files from config to worktree
(cd "$CONTEXT_SRC" && find . \( -name 'CLAUDE.local.md' -o -name 'AGENTS.md' \) -exec sh -c '
  for file; do
    mkdir -p "'"$worktree_path"'/$(dirname "$file")"
    cp "$file" "'"$worktree_path"'/$file"
  done
' _ {} +)

if [[ "$no_setup" == false ]]; then
  log_file=$(mktemp)
  if (
    (cd "$worktree_path" && bash "$SETUP_CMD" > "$log_file" 2>&1) &
    pid=$!
    spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    i=0
    while kill -0 $pid 2>/dev/null; do
      printf "\r  ${spin:$i:1} Setting up worktree..."
      i=$(( (i + 1) % ${#spin} ))
      sleep 0.1
    done
    wait $pid
  ); then
    exit_code=0
  else
    exit_code=$?
  fi
  printf "\r\033[K"
  if [ "$exit_code" -ne 0 ]; then
    echo "Worktree setup failed. Log: $log_file"
    exit 1
  fi
  rm -f "$log_file"
  echo "✔ Worktree setup complete"
fi

echo "Worktree ready: $worktree_path"
