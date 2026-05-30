#!/bin/bash
set -euo pipefail

. "$HOME/.config/dev/lib/workspace.sh"

### gwc.sh — Create git worktree with dev environment
### Sets up a new worktree, copies context files, syncs existing worktrees, and runs setup-stack.sh.
###
### Usage:
###   gwc [-n|--no-setup] [-b|--base <ref>] <branch-name>
###
### Options:
###   -n, --no-setup    Skip running setup-stack.sh (just create worktree)
###   -b, --base <ref>  Base branch/ref for a new branch (bare names resolve to
###                     origin/<ref> first, then local <ref>). Overrides GWC_BASE_REF.
###                     Only used when <branch-name> doesn't already exist.
###
### Examples:
###   gwc feat/my-feature              Create worktree from origin/HEAD and setup stack
###   gwc -b develop feat/my-feature   Branch off origin/develop instead of the default
###   gwc -n fix/quick-patch           Create worktree without running setup

WORKTREE_BASE="$(dev_worktree_base)"
SETUP_CMD="/Users/philip/.config/dev/setup-stack.sh"
CONTEXT_SRC="/Users/philip/.config/dev/context/ledidi-monorepo"

# Resolve an explicit base ref. Bare names prefer origin/<ref>, then local <ref>;
# fully-qualified refs (origin/x), tags, and SHAs are used as-is.
resolve_base_ref() {
  local ref="$1"

  if [[ "$ref" == */* ]] && git show-ref --verify --quiet "refs/remotes/$ref"; then
    printf '%s\n' "$ref"
    return 0
  fi

  if git show-ref --verify --quiet "refs/remotes/origin/$ref"; then
    printf '%s\n' "origin/$ref"
    return 0
  fi

  if git show-ref --verify --quiet "refs/heads/$ref"; then
    printf '%s\n' "$ref"
    return 0
  fi

  if git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
    printf '%s\n' "$ref"
    return 0
  fi

  echo "Error: Could not resolve base ref '$ref' (tried origin/$ref and local $ref)." >&2
  exit 1
}

default_base_ref() {
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
  echo "Pass -b <ref> or set GWC_BASE_REF, for example: gwc -b origin/main <branch>" >&2
  exit 1
}

no_setup=false
base_override="${GWC_BASE_REF:-}"
while [[ "${1:-}" == -* ]]; do
  case "$1" in
    -n|--no-setup) no_setup=true; shift ;;
    -b|--base)
      [[ -n "${2:-}" ]] || { echo "Error: $1 requires a value"; exit 1; }
      base_override="$2"; shift 2 ;;
    --base=*) base_override="${1#*=}"; shift ;;
    *) echo "Unknown flag: $1"; exit 1 ;;
  esac
done

if [[ -z "${1:-}" ]]; then
  echo "Usage: gwc [-n|--no-setup] [-b|--base <ref>] <branch-name>"
  exit 1
fi

branch="$1"
worktree_path="$WORKTREE_BASE/${branch##*/}"

# Must be in a git repo
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "Error: Not inside a git repository"; exit 1; }

dev_prune_stale_slot_files

git fetch origin
if [[ -n "$base_override" ]]; then
  base_ref=$(resolve_base_ref "$base_override")
else
  base_ref=$(default_base_ref)
fi

if git show-ref --verify --quiet "refs/heads/$branch"; then
  git worktree add "$worktree_path" "$branch" || exit 1
elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  git worktree add "$worktree_path" "$branch" || exit 1
else
  echo "Creating '$branch' from $base_ref"
  git worktree add -b "$branch" "$worktree_path" "$base_ref" || exit 1
fi

# Copy raw context templates to new worktree (placeholders will be replaced by dev up)
(cd "$CONTEXT_SRC" && find . \( -name 'CLAUDE.local.md' -o -name 'AGENTS.md' \) -exec sh -c '
  for file; do
    mkdir -p "'"$worktree_path"'/$(dirname "$file")"
    cp "$file" "'"$worktree_path"'/$file"
  done
' _ {} +)

# Sync context files with port replacements for existing worktrees (that have slots)
"$HOME/.config/dev/sync-context.sh"

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
