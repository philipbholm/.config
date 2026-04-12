#!/bin/bash
set -euo pipefail

. "$HOME/.config/dev/lib/workspace.sh"

CONTEXT_DIR="$HOME/.config/dev/context/ledidi-monorepo"
CLAUDE_TEMPLATE="$CONTEXT_DIR/CLAUDE.local.md"
AGENTS_TEMPLATE="$CONTEXT_DIR/AGENTS.md"
MAIN_REPO="$HOME/work/ledidi-monorepo"
WORKTREE_BASE="$(dev_worktree_base)"

apply_replacements() {
  local file="$1"

  sed -i '' \
    -e "s|{{FRONTEND_PORT}}|$(( 3003 + offset ))|g" \
    -e "s|{{ROUTER_PORT}}|$(( 4000 + offset ))|g" \
    -e "s|{{POSTGRES_PORT}}|$(( 5432 + offset ))|g" \
    -e "s|{{CODELIST_PORT}}|$(( 4005 + offset ))|g" \
    -e "s|{{CODELIST_GRPC_PORT}}|$(( 50005 + offset ))|g" \
    -e "s|{{REGISTRIES_PORT}}|$(( 4006 + offset ))|g" \
    -e "s|{{REGISTRIES_GRPC_PORT}}|$(( 50006 + offset ))|g" \
    -e "s|{{AGENT_PORT}}|$(( 4007 + offset ))|g" \
    "$file"
}

for template in "$CLAUDE_TEMPLATE" "$AGENTS_TEMPLATE"; do
  if [[ ! -f "$template" ]]; then
    echo "Template not found: $template" >&2
    exit 1
  fi
done

targets=()

if [[ -d "$MAIN_REPO" ]]; then
  targets+=("$MAIN_REPO:0")
fi

while IFS= read -r git_file; do
  wt=$(dirname "$git_file")
  slot_file="$(dev_slot_file_for_repo "$wt")"
  if [[ -f "$slot_file" ]]; then
    targets+=("$wt:$(< "$slot_file")")
  fi
done < <(find "$WORKTREE_BASE" -type f -name .git 2>/dev/null | sort)

if (( ${#targets[@]} == 0 )); then
  echo "No targets found"
  exit 0
fi

count=0
for entry in "${targets[@]}"; do
  target="${entry%%:*}"
  slot="${entry##*:}"
  offset=$(( slot * 100 ))
  claude_dest="$target/CLAUDE.local.md"
  agents_dest="$target/AGENTS.md"

  cp "$CLAUDE_TEMPLATE" "$claude_dest"
  cp "$AGENTS_TEMPLATE" "$agents_dest"

  apply_replacements "$claude_dest"
  apply_replacements "$agents_dest"

  count=$(( count + 1 ))
  echo "  ✓ ${target##*/} (slot $slot)"
done

echo "Synced context to $count workspace(s)"
