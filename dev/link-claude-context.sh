#!/bin/bash
set -euo pipefail

repo_root="${1:-$(pwd)}"
template_root="${CLAUDE_TEMPLATE_ROOT:-$HOME/.config/dev/claude/ledidi-monorepo}"
tmp_root="${WORKTREE_TMP_DIR:-$HOME/work/tmp/dev-stacks}"
project_name="$(basename "$repo_root")"
context_dir="$tmp_root/$project_name/agent-context"

if [ ! -d "$template_root" ]; then
  echo "Error: template root not found: $template_root" >&2
  exit 1
fi

mkdir -p "$context_dir"

ensure_symlink() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "Skipping existing non-symlink: $dst"
    return
  fi
  ln -sfn "$src" "$dst"
}

bootstrap_root_local_context() {
  local src="$template_root/CLAUDE.local.md"
  local dst="$context_dir/CLAUDE.local.md"
  if [ ! -f "$dst" ]; then
    cp "$src" "$dst"
    sed -i '' '/App runs at http:\/\/localhost:3001\/en\/registries/d' "$dst"
  fi
  ensure_symlink "$dst" "$repo_root/CLAUDE.local.md"
}

symlink_template_files() {
  while IFS= read -r rel; do
    [ "$rel" = "./CLAUDE.local.md" ] && continue
    local src="$template_root/${rel#./}"
    local dst="$repo_root/${rel#./}"
    ensure_symlink "$src" "$dst"
  done < <(cd "$template_root" && find . \( -name 'CLAUDE.local.md' -o -name 'AGENTS.md' \) -type f | sort)
}

bootstrap_root_local_context
symlink_template_files

echo "Linked Claude/Codex context into: $repo_root"
