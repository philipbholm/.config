#!/bin/bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: Not inside a git repository"
    exit 1
}
cd "$REPO_ROOT"

### setup-stack.sh — Prepare a checkout or worktree for work
### npm install, type generation, supergraph composition, and agent context
### files. Starts no containers — Docker and ports come from `dev up`.
###
### Usage:
###   setup-stack                    Install the workspaces the dev stack builds
###   setup-stack --all              Also install every workspace lefthook gates
###   setup-stack apps/shell         Also install the named workspaces
###
### Flags:
###   --all              Install every workspace listed in lefthook.yml's
###                      `extends:` as well, so a branch touching one of them
###                      has the node_modules its pre-commit and pre-push hooks
###                      need. Slower and several GB heavier per worktree, which
###                      is why it is opt-in.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

step() {
    echo ""
    echo -e "${GREEN}${BOLD}==>${NC} ${BOLD}$1${NC}"
}

warn() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

fail() {
    echo -e "${RED}Error:${NC} $1"
    exit 1
}

list_contains() {
    local needle=$1
    shift

    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

# The workspaces lefthook runs pre-commit and pre-push commands in. Read from
# the file itself so the two lists cannot drift: a workspace added there needs
# node_modules on any branch that touches it, or its `npx tsc --noEmit` fails
# for a reason the branch's own code cannot explain.
lefthook_gated_workspaces() {
    local lefthook="$REPO_ROOT/lefthook.yml"

    [ -f "$lefthook" ] || return 0

    awk '
        /^extends:/ { in_extends = 1; next }
        in_extends && /^[^[:space:]]/ { in_extends = 0 }
        in_extends && /lefthook\.yml/ {
            sub(/^[[:space:]]*-[[:space:]]*/, "")
            sub(/\/lefthook\.yml[[:space:]]*$/, "")
            if ($0 != "") print
        }
    ' "$lefthook"
}

add_workspace() {
    local ws=${1%/}

    [ -n "$ws" ] || return 0
    list_contains "$ws" ${install_workspaces[@]+"${install_workspaces[@]}"} && return 0

    if [ ! -d "$REPO_ROOT/$ws" ]; then
        warn "$ws is not in this checkout — skipped"
        return 0
    fi

    install_workspaces+=("$ws")
}

install_workspace() {
    local ws=$1

    if [ ! -f "$REPO_ROOT/$ws/package.json" ]; then
        warn "$ws has no package.json — skipped"
        return 0
    fi

    # `npm ci` needs a lockfile, and packages/components has none — `packages/`
    # gitignores them, so don't write one either.
    if [ -f "$REPO_ROOT/$ws/package-lock.json" ]; then
        (cd "$REPO_ROOT/$ws" && npm ci --loglevel=warn)
    else
        (cd "$REPO_ROOT/$ws" && npm install --no-package-lock --loglevel=warn)
    fi
}

install_all=false
extra_workspaces=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --all)
            install_all=true
            shift
            ;;
        -*)
            fail "unknown flag: $1 (see the header of $0)"
            ;;
        /*|*..*)
            fail "workspace must be a path inside the repo, relative to its root: $1"
            ;;
        *)
            extra_workspaces+=("$1")
            shift
            ;;
    esac
done

# Check GITHUB_TOKEN is available (needed for @ledidi-as scoped packages)
if [ -z "${GITHUB_TOKEN:-}" ]; then
    warn "GITHUB_TOKEN is not set. npm install may fail for @ledidi-as scoped packages."
    echo "  Set it with: export GITHUB_TOKEN=<your-token>"
fi

# The dev stack and the codegen steps below need exactly these three.
install_workspaces=(apps/registries-frontend services/codelist services/registries)

if [ "$install_all" = true ]; then
    gated_count=0
    while IFS= read -r ws; do
        gated_count=$(( gated_count + 1 ))
        add_workspace "$ws"
    done < <(lefthook_gated_workspaces)

    if [ "$gated_count" -eq 0 ]; then
        warn "--all found no workspaces in $REPO_ROOT/lefthook.yml's extends: list"
    fi
fi

for ws in ${extra_workspaces[@]+"${extra_workspaces[@]}"}; do
    [ -d "$REPO_ROOT/${ws%/}" ] || fail "no such workspace in this checkout: $ws"
    add_workspace "$ws"
done

# ------------------------------------------------------------------
# 1. npm install for each workspace
# ------------------------------------------------------------------
step "Installing npm dependencies"

failed_workspaces=()
for ws in "${install_workspaces[@]}"; do
    echo "  $ws ..."
    install_workspace "$ws" || failed_workspaces+=("$ws")
done

# Keep going through the whole list first: a failure in one workspace says
# nothing about the others, and stopping mid-loop leaves them uninstalled.
if [ "${#failed_workspaces[@]}" -gt 0 ]; then
    fail "npm install failed in: ${failed_workspaces[*]}"
fi

# ------------------------------------------------------------------
# 2. Generate types for backend services
# ------------------------------------------------------------------
step "Generating types for backend services"

for svc in services/codelist services/registries; do
    echo "  $svc ..."
    (cd "$REPO_ROOT/$svc" && npm run generate) || fail "generate failed in $svc"
done

# ------------------------------------------------------------------
# 3. Compose Apollo Router supergraph
# ------------------------------------------------------------------
step "Composing Apollo Router supergraph"

(cd "$REPO_ROOT/services/apollo-router" && ./compose-supergraph.sh) || fail "supergraph composition failed"

# ------------------------------------------------------------------
# 4. Generate frontend GraphQL types (needs supergraph + service schemas)
# ------------------------------------------------------------------
step "Generating frontend types"

(cd "$REPO_ROOT/apps/registries-frontend" && npm run generate) || fail "frontend generate failed"

# ------------------------------------------------------------------
# 5. Agent context files
# ------------------------------------------------------------------
# CLAUDE.local.md and AGENTS.md are untracked, so a fresh worktree has none
# until something writes them. `dev up` is the other writer, and the whole
# point of this script is the tiers of work that never start a stack.
step "Syncing agent context"

"$HOME/.config/dev/sync-context.sh" ||
    warn "context sync failed — CLAUDE.local.md and AGENTS.md may be missing or stale"

# ------------------------------------------------------------------
# Done
# ------------------------------------------------------------------
uninstalled_gated=()
while IFS= read -r ws; do
    [ -n "$ws" ] || continue
    [ -d "$REPO_ROOT/$ws" ] || continue
    [ -d "$REPO_ROOT/$ws/node_modules" ] && continue
    list_contains "$ws" "${install_workspaces[@]}" && continue
    uninstalled_gated+=("$ws")
done < <(lefthook_gated_workspaces)

if [ "${#uninstalled_gated[@]}" -gt 0 ]; then
    echo ""
    warn "lefthook also gates ${uninstalled_gated[*]}, which have no node_modules."
    echo "  Their pre-commit and pre-push commands fail there until you run"
    echo "  'setup-stack ${uninstalled_gated[*]}' (or 'setup-stack --all')."
fi

echo ""
echo -e "${GREEN}${BOLD}Stack setup complete.${NC}"
