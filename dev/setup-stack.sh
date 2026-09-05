#!/bin/bash
set -euo pipefail

### setup-stack.sh — Install dependencies and generate types in named workspaces
### Starts no containers — Docker and ports come from `dev up`.
###
### Usage:
###   setup-stack services/registries
###   setup-stack apps/registries-frontend services/codelist

usage() {
    echo "Usage: setup-stack <workspace> [workspace ...]"
    echo "Install dependencies and run each named workspace's generate script, if present."
    echo "Example: setup-stack services/registries"
}

if [ "$#" -eq 0 ]; then
    usage >&2
    exit 1
fi
if [ "$#" -eq 1 ] && { [ "$1" = "--help" ] || [ "$1" = "-h" ]; }; then
    usage
    exit 0
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "Error: Not inside a git repository" >&2
    exit 1
}
cd "$REPO_ROOT"
REPO_ROOT=$(pwd -P)

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

add_workspace() {
    local ws=${1%/}
    local workspace_path

    [ -d "$REPO_ROOT/$ws" ] || fail "no such workspace in this checkout: $ws"
    workspace_path=$(cd "$REPO_ROOT/$ws" && pwd -P)
    case "$workspace_path" in
        "$REPO_ROOT"/*) ws=${workspace_path#"$REPO_ROOT"/} ;;
        *) fail "workspace must be inside this checkout: $ws" ;;
    esac
    [ -f "$workspace_path/package.json" ] || fail "$ws has no package.json"

    list_contains "$ws" ${install_workspaces[@]+"${install_workspaces[@]}"} && return 0
    install_workspaces+=("$ws")
}

install_workspace() {
    local ws=$1

    # `npm ci` needs a lockfile, and packages/components has none — `packages/`
    # gitignores them, so don't write one either.
    if [ -f "$REPO_ROOT/$ws/package-lock.json" ]; then
        (cd "$REPO_ROOT/$ws" && npm ci --loglevel=warn)
    else
        (cd "$REPO_ROOT/$ws" && npm install --no-package-lock --loglevel=warn)
    fi
}

install_workspaces=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        -*)
            fail "unknown flag: $1 (see setup-stack --help)"
            ;;
        /*|*..*)
            fail "workspace must be a path inside the repo, relative to its root: $1"
            ;;
        *)
            add_workspace "$1"
            shift
            ;;
    esac
done

# Check GITHUB_TOKEN is available (needed for @ledidi-as scoped packages)
if [ -z "${GITHUB_TOKEN:-}" ]; then
    warn "GITHUB_TOKEN is not set. npm install may fail for @ledidi-as scoped packages."
    echo "  Set it with: export GITHUB_TOKEN=<your-token>"
fi

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

step "Generating types in selected workspaces"
for ws in "${install_workspaces[@]}"; do
    echo "  $ws ..."
    (cd "$REPO_ROOT/$ws" && npm run generate --if-present) || fail "generate failed in $ws"
done

echo ""
echo -e "${GREEN}${BOLD}Workspace setup complete.${NC}"
