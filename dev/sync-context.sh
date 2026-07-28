#!/bin/bash
set -euo pipefail

. "$HOME/.config/dev/lib/workspace.sh"

CONTEXT_DIR="$HOME/.config/dev/context/ledidi-monorepo"
CLAUDE_TEMPLATE="$CONTEXT_DIR/CLAUDE.local.md"
AGENTS_TEMPLATE="$CONTEXT_DIR/AGENTS.md"
MAIN_REPO="$HOME/work/ledidi-monorepo"
WORKTREE_BASE="$(dev_worktree_base_for_repo "$MAIN_REPO")"

NO_STACK="no-stack"

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

# Worktrees without a Docker stack have no ports to substitute. Replace the
# body of the self-contained "## Ports (Worktree-Specific)" section — up to the
# next `## ` heading — rather than leaving raw {{PLACEHOLDER}} tokens behind.
replace_port_section() {
  local file="$1"
  local tmp
  tmp="$(mktemp)"

  awk '
    /^## Ports \(Worktree-Specific\)$/ {
      print
      print ""
      print "No dev stack is running for this worktree. Run `dev up` to start one, then re-run `sync-context` to populate the port table."
      print ""
      skipping = 1
      next
    }
    skipping && /^## / { skipping = 0 }
    !skipping { print }
  ' "$file" > "$tmp"

  mv "$tmp" "$file"
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
    targets+=("$wt:$(tr -d '[:space:]' < "$slot_file")")
  else
    targets+=("$wt:$NO_STACK")
  fi
done < <(find "$WORKTREE_BASE" -type f -name .git 2>/dev/null)

if (( ${#targets[@]} == 0 )); then
  echo "No targets found"
  exit 0
fi

# Sort targets by slot offset ("no-stack" sorts alongside 0, which is fine)
IFS=$'\n' targets=($(printf '%s\n' "${targets[@]}" | sort -t: -k2 -n))
unset IFS

# Check for duplicate slots (single pass using sort | uniq -d).
# Slotless worktrees are excluded — they own no slot to collide over.
duplicate_found=false
duplicates=$(printf '%s\n' "${targets[@]}" | sed 's/.*://' | grep -v "^${NO_STACK}$" | sort -n | uniq -d)
if [[ -n "$duplicates" ]]; then
  duplicate_found=true
  while IFS= read -r slot; do
    echo "Warning: slot $slot is assigned to multiple worktrees:" >&2
    for entry in "${targets[@]}"; do
      if [[ "${entry##*:}" == "$slot" ]]; then
        echo "  - ${entry%%:*}" | sed 's|.*/||' >&2
      fi
    done
  done <<< "$duplicates"
fi

if [[ "$duplicate_found" == true ]]; then
  echo "Warning: run 'dev up' in a conflicting worktree to reassign its saved slot." >&2
fi

count=0
for entry in "${targets[@]}"; do
  target="${entry%%:*}"
  slot="${entry##*:}"
  claude_dest="$target/CLAUDE.local.md"
  agents_dest="$target/AGENTS.md"

  cp "$CLAUDE_TEMPLATE" "$claude_dest"
  cp "$AGENTS_TEMPLATE" "$agents_dest"

  if [[ "$slot" == "$NO_STACK" ]]; then
    replace_port_section "$claude_dest"
    replace_port_section "$agents_dest"
    echo "  ✓ ${target##*/} (no stack)"
  else
    offset=$(( slot * 100 ))
    apply_replacements "$claude_dest"
    apply_replacements "$agents_dest"
    echo "  ✓ ${target##*/} (slot $slot)"
  fi

  count=$(( count + 1 ))
done

echo "Synced context to $count workspace(s)"
