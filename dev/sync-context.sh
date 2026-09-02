#!/bin/bash
set -euo pipefail

. "$HOME/.config/dev/lib/workspace.sh"

CONTEXT_DIR="$HOME/.config/dev/context/ledidi-monorepo"
CONTEXT_TEMPLATE="$CONTEXT_DIR/AGENTS.md"
MAIN_REPO="$HOME/work/ledidi-monorepo"

NO_STACK="no-stack"

# Rewrites one self-contained section of a rendered context file: the heading
# line $2 and everything up to the next heading matching $3 become $4.
replace_section() {
  local file="$1"
  local heading="$2"
  local stop="$3"
  local replacement="$4"
  local tmp line
  local skipping=false
  local found=false

  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "$heading" ]]; then
      printf '%s\n' "$replacement"
      skipping=true
      found=true
      continue
    fi
    if [[ "$skipping" == true ]]; then
      [[ "$line" =~ $stop ]] || continue
      skipping=false
    fi
    printf '%s\n' "$line"
  done < "$file" > "$tmp"

  cat "$tmp" > "$file"
  rm -f "$tmp"

  if [[ "$found" == false ]]; then
    echo "Warning: '$heading' is no longer in the templates, so ${file##*/} keeps their wording." >&2
  fi
}

# Swaps the first paragraph — the run of non-blank lines starting at the line
# matching $2 — for $3, leaving the headings and tables around it alone.
replace_paragraph() {
  local file="$1"
  local anchor="$2"
  local replacement="$3"
  local tmp line
  local skipping=false
  local found=false

  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$found" == false && "$line" =~ $anchor ]]; then
      printf '%s\n' "$replacement"
      skipping=true
      found=true
      continue
    fi
    if [[ "$skipping" == true ]]; then
      [[ -z "$line" ]] || continue
      skipping=false
    fi
    printf '%s\n' "$line"
  done < "$file" > "$tmp"

  cat "$tmp" > "$file"
  rm -f "$tmp"

  if [[ "$found" == false ]]; then
    echo "Warning: no paragraph matching /$anchor/ in ${file##*/}, so it keeps the templates' wording." >&2
  fi
}

# Worktrees without a Docker stack have no ports to substitute. Replace the
# body of the self-contained "## Ports (Worktree-Specific)" section — up to the
# next `## ` heading — rather than leaving raw {{PLACEHOLDER}} tokens behind.
replace_port_section() {
  local body
  body='## Ports (Worktree-Specific)

No dev stack is running for this worktree, so it has no ports yet. Start only what the task needs: `dev up postgres -d` for the backend suite, `dev up` for browser work or E2E. Either one fills in this table.
'

  replace_section "$1" '## Ports (Worktree-Specific)' '^## ' "$body"
}

# Same for the main checkout, which is not a worktree and whose stack lives on
# the base ports. The placeholders are filled in afterwards at slot 0.
replace_main_port_section() {
  local body
  body='## Ports (Main Checkout)

No dev stack is running for the main checkout, so it has no ports yet. `dev up`
here starts the slot-0 stack — the one no worktree owns — on the base ports:
frontend {{FRONTEND_PORT}}, registries {{REGISTRIES_PORT}}, PostgreSQL {{POSTGRES_PORT}}.
Start it only for work on the main checkout itself.
'

  replace_section "$1" '## Ports (Worktree-Specific)' '^## ' "$body"
}

# The port table itself is right for the main checkout at slot 0. Only the prose
# around it needs to stop calling this a worktree and the base ports somebody
# else's.
replace_main_port_prose() {
  local file="$1"
  local heading intro caveat

  heading='## Ports (Main Checkout)'
  intro='This is the main checkout, and the ports below are the base set it publishes.
Each parallel worktree runs its own stack 100 higher per slot, so none of these
numbers are shared with them.'
  caveat="These ports belong to the main checkout, and they are correct as listed. When
one doesn't respond, the Docker stack is what needs attention — editing
hardcoded URLs, env files, or configs to reach a service breaks the checkout
instead of fixing it."
  replace_paragraph "$file" '^## Ports \(Worktree-Specific\)$' "$heading"
  replace_paragraph "$file" '^This is one of many parallel worktrees,' "$intro"
  replace_paragraph "$file" '^These ports belong to this worktree alone' "$caveat"
}

# `wt-down` exits 1 in the main checkout by design, so the teardown rules there
# are about the shared slot-0 stack instead.
replace_main_teardown_section() {
  local body
  body='### Tearing down

This is the main checkout, not a worktree, so `wt-down` refuses to run here and
there is no directory to remove. Its stack is the one nothing else owns: never
run `dev down` or `dev nuke` here on your own initiative, and a green suite is
not a reason to stop it.

`dev restart <service>` and `dev up --build <service>` are not teardown — use
them freely while working.

When you finish with containers still running, name the stack and its ports so
nothing is left running silently.
'

  replace_section "$1" '### Tearing down' '^##+ ' "$body"
}

if [[ ! -f "$CONTEXT_TEMPLATE" ]]; then
  echo "Template not found: $CONTEXT_TEMPLATE" >&2
  exit 1
fi

if [[ "$(head -n 1 "$CONTEXT_TEMPLATE")" != '# AGENTS.md' ]]; then
  echo "Template must start with '# AGENTS.md': $CONTEXT_TEMPLATE" >&2
  exit 1
fi

# dev.sh writes a slot file for worktrees only, so the main checkout's stack has
# to be read out of Docker. Slot 0 is its number, in dev.sh's main mode and in
# the labels that mode stamps on the containers.
main_repo_slot() {
  local containers
  containers="$(docker ps -q --filter "label=${DEV_SLOT_LABEL}=0" 2>/dev/null || true)"

  if [[ -n "$containers" ]]; then
    printf '0\n'
  else
    printf '%s\n' "$NO_STACK"
  fi
}

targets=()

if [[ -d "$MAIN_REPO" ]]; then
  targets+=("$MAIN_REPO:$(main_repo_slot)")
fi

# Ask Git for every registered worktree instead of assuming a harness-specific
# directory. This covers native `.worktrees`, legacy Claude worktrees, and
# Codex-managed worktrees outside the repository.
while IFS= read -r wt; do
  [[ "$wt" == "$MAIN_REPO" ]] && continue
  [[ -d "$wt" ]] || continue

  slot_file="$(dev_slot_file_for_repo "$wt")"
  if [[ -f "$slot_file" ]]; then
    targets+=("$wt:$(tr -d '[:space:]' < "$slot_file")")
  else
    targets+=("$wt:$NO_STACK")
  fi
done < <(git -C "$MAIN_REPO" worktree list --porcelain | sed -n 's/^worktree //p')

if (( ${#targets[@]} == 0 )); then
  echo "No targets found"
  exit 0
fi

# Sort targets by slot offset ("no-stack" sorts alongside 0, which is fine)
sorted_targets=()
while IFS= read -r entry; do
  [[ -n "$entry" ]] && sorted_targets+=("$entry")
done < <(printf '%s\n' "${targets[@]}" | sort -t: -k2 -n)
targets=("${sorted_targets[@]}")

# Check for duplicate slots (single pass using sort | uniq -d).
# Slotless worktrees are excluded — they own no slot to collide over. When every
# target is slotless the grep selects nothing and exits 1, which under pipefail
# would abort the whole sync before a single file is written, so absorb it.
duplicate_found=false
duplicates=$(printf '%s\n' "${targets[@]}" | sed 's/.*://' | { grep -v "^${NO_STACK}$" || true; } | sort -n | uniq -d)
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

  cp "$CONTEXT_TEMPLATE" "$agents_dest"
  sed '1s/^# AGENTS\.md$/# CLAUDE.local.md/' "$CONTEXT_TEMPLATE" > "$claude_dest"

  if [[ "$target" == "$MAIN_REPO" ]]; then
    # The templates are written for a worktree. The main checkout follows the
    # same rules, but not the ones about ports it doesn't own or a directory it
    # cannot remove.
    for dest in "$claude_dest" "$agents_dest"; do
      replace_main_teardown_section "$dest"
      if [[ "$slot" == "$NO_STACK" ]]; then
        replace_main_port_section "$dest"
      else
        replace_main_port_prose "$dest"
      fi
      dev_apply_context_ports "$dest" 0
    done

    if [[ "$slot" == "$NO_STACK" ]]; then
      echo "  ✓ ${target##*/} (main, no stack)"
    else
      echo "  ✓ ${target##*/} (main, slot 0)"
    fi
  elif [[ "$slot" == "$NO_STACK" ]]; then
    replace_port_section "$claude_dest"
    replace_port_section "$agents_dest"
    echo "  ✓ ${target##*/} (no stack)"
  else
    dev_apply_context_ports "$claude_dest" "$slot"
    dev_apply_context_ports "$agents_dest" "$slot"
    echo "  ✓ ${target##*/} (slot $slot)"
  fi

  count=$(( count + 1 ))
done

echo "Synced context to $count workspace(s)"
