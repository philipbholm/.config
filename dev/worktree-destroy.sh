#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/lib/cli.sh"
dev_help_if_requested worktree-destroy "$@"
[[ $# -eq 0 ]] || dev_cli_error "dev worktree destroy takes no arguments"
. "$SCRIPT_DIR/lib/checkout.sh"

DEV_CMD="$SCRIPT_DIR/stack.sh"

worktree_path=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Error: not inside a git repository" >&2
  exit 1
}

git_dir=$(git -C "$worktree_path" rev-parse --absolute-git-dir)
common_dir=$(dev_git_common_dir_abs "$worktree_path") || {
  echo "Error: could not resolve the git common dir" >&2
  exit 1
}

if [[ "$git_dir" == "$common_dir" ]]; then
  echo "Error: $worktree_path is the main working tree, not a worktree." >&2
  echo "Run dev worktree destroy from inside the worktree you want to remove." >&2
  exit 1
fi

if ! dev_is_worktree_repo "$worktree_path"; then
  echo "Error: $worktree_path/.git is not a worktree pointer file." >&2
  exit 1
fi

dirty=$(git -C "$worktree_path" status --porcelain)
if [[ -n "$dirty" ]]; then
  echo "Error: worktree has uncommitted changes. Commit, stash, or discard them first." >&2
  echo "$dirty" >&2
  exit 1
fi

main_repo=$(dirname "$common_dir")
branch=$(git -C "$worktree_path" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "(detached)")
project_name=$(dev_checkout_id_for_repo "$worktree_path")

echo "Tearing down $worktree_path (branch: $branch)"

slot_file=$(dev_existing_slot_file_for_repo "$worktree_path" 2>/dev/null || true)
existing_containers=$(docker ps -aq --filter "label=${DEV_CHECKOUT_LABEL}=${project_name}" 2>/dev/null || true)

if [[ -n "$slot_file" || -n "$existing_containers" ]]; then
  echo "  Nuking dev stack ($project_name)..."
  # Running dev worktree destroy is the confirmation, and `dev stack destroy` refuses to assume one
  # when there is no terminal to prompt on.
  (cd "$worktree_path" && bash "$DEV_CMD" destroy --yes)

  # `dev stack destroy` exits 0 when its own prompt is answered "n", so removing the
  # directory has to be gated on the stack actually being gone — otherwise the
  # containers and one of the nine slots are orphaned with no way back to them.
  leftover=$(docker ps -aq --filter "label=${DEV_CHECKOUT_LABEL}=${project_name}" 2>/dev/null || true)
  if [[ -n "$leftover" ]]; then
    echo "Error: containers for $project_name are still there, so $worktree_path was kept." >&2
    docker ps -a --filter "label=${DEV_CHECKOUT_LABEL}=${project_name}" >&2 || true
    echo "Remove them ('dev stack destroy --yes' inside the worktree) and re-run dev worktree destroy." >&2
    exit 1
  fi
fi

echo "  Removing worktree..."
# Step out of the directory we are about to delete: this script's own remaining
# commands run with a cwd that no longer exists otherwise, and bash greets each
# child process with a getcwd error. The caller is a separate process — a
# caller has to cd out on its own.
cd "$main_repo"
git -C "$main_repo" worktree remove "$worktree_path"
git -C "$main_repo" worktree prune

dev_prune_stale_slot_files
if [[ "$main_repo" == "${DEV_MAIN_REPO:-$HOME/work/ledidi-monorepo}" ]]; then
  bash "$SCRIPT_DIR/context-render.sh" ||
    echo "Warning: context render failed; CLAUDE.local.md and AGENTS.md may be stale." >&2
fi

echo "Removed $worktree_path. Branch '$branch' still exists — 'git branch -d $branch' to delete it."
