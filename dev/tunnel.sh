#!/bin/bash

### This script starts cloudflared tunnels for the frontend and API,
### configures the app to work through them, and cleans up on exit.

set -euo pipefail

. "$HOME/.config/dev/lib/workspace.sh"

# Ensure Docker CLI is in PATH (Docker Desktop on macOS)
[[ -d "/Applications/Docker.app/Contents/Resources/bin" ]] && \
    export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"

if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "Error: Not inside a git repository" >&2
    exit 1
fi
MONOREPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$MONOREPO_ROOT"
PROJECT_NAME="$(dev_workspace_id_for_repo "$MONOREPO_ROOT")"
FRONTEND_BASE_PORT=3003

# Determine ports from worktree slot
worktree_slot_file="$(dev_slot_file_for_repo "$MONOREPO_ROOT")"
if [[ -f "$worktree_slot_file" ]]; then
  slot=$(cat "$worktree_slot_file")
  offset=$((slot * 100))
  frontend_port=$((FRONTEND_BASE_PORT + offset))
  api_port=$((4006 + offset))
else
  frontend_port=$FRONTEND_BASE_PORT
  api_port=4006
fi

# docker compose wrapper: use stack compose file from tmp dir when present
dc() {
  local stack_compose="$TMP_BASE/docker-compose.stack.yml"
  if [[ -f "$stack_compose" ]]; then
    COMPOSE_PROJECT_NAME="$PROJECT_NAME" docker compose \
      -f docker-compose.yml -f "$stack_compose" "$@"
  else
    COMPOSE_PROJECT_NAME="$PROJECT_NAME" docker compose "$@"
  fi
}

# Files that will be modified (git-tracked, reverted via git checkout)
AMPLIFY_CONFIG="$MONOREPO_ROOT/apps/registries-frontend/src/features/auth/amplify-config.ts"
VITE_CONFIG="$MONOREPO_ROOT/apps/registries-frontend/vite.config.ts"
DOCKER_COMPOSE="$MONOREPO_ROOT/docker-compose.yml"
ROUTER_CONFIG="$MONOREPO_ROOT/services/apollo-router/router.docker.yaml"

# Worktree overlay files (outside git, backed up/restored manually)
TMP_BASE="$(dev_stack_dir_for_repo "$MONOREPO_ROOT")"
WT_COMPOSE="$TMP_BASE/docker-compose.stack.yml"
WT_ROUTER_CONFIG="$TMP_BASE/router.docker.worktree.yaml"
WT_COMPOSE_BACKUP=""
WT_ROUTER_BACKUP=""

# Process IDs for cleanup
FRONTEND_TUNNEL_PID=""
API_TUNNEL_PID=""

# Tunnel URLs
FRONTEND_URL=""
API_URL=""

# Temp files for capturing tunnel output
FRONTEND_LOG=$(mktemp)
API_LOG=$(mktemp)

#######################################
# Cleanup function - runs on script exit
#######################################
cleanup() {
    echo ""
    echo "Cleaning up..."

    # Kill tunnel processes
    if [ -n "$FRONTEND_TUNNEL_PID" ] && kill -0 "$FRONTEND_TUNNEL_PID" 2>/dev/null; then
        echo "Stopping frontend tunnel (PID: $FRONTEND_TUNNEL_PID)..."
        kill "$FRONTEND_TUNNEL_PID" 2>/dev/null || true
    fi

    if [ -n "$API_TUNNEL_PID" ] && kill -0 "$API_TUNNEL_PID" 2>/dev/null; then
        echo "Stopping API tunnel (PID: $API_TUNNEL_PID)..."
        kill "$API_TUNNEL_PID" 2>/dev/null || true
    fi

    # Revert git-tracked config file changes
    echo "Reverting config file changes..."
    cd "$MONOREPO_ROOT"
    git checkout -- "$AMPLIFY_CONFIG" "$VITE_CONFIG" "$DOCKER_COMPOSE" "$ROUTER_CONFIG" 2>/dev/null || true

    # Restore worktree overlay files from backups
    if [[ -n "$WT_COMPOSE_BACKUP" && -f "$WT_COMPOSE_BACKUP" ]]; then
        cp "$WT_COMPOSE_BACKUP" "$WT_COMPOSE"
        rm -f "$WT_COMPOSE_BACKUP"
    fi
    if [[ -n "$WT_ROUTER_BACKUP" && -f "$WT_ROUTER_BACKUP" ]]; then
        cp "$WT_ROUTER_BACKUP" "$WT_ROUTER_CONFIG"
        rm -f "$WT_ROUTER_BACKUP"
    fi
    # Rebuild frontend to restore clean vite.config.ts in the container image
    # (vite.config.ts is not volume-mounted, so it's baked into the image)
    echo "Rebuilding frontend with clean config..."
    dc build registries-frontend 2>/dev/null && dc up -d registries-frontend 2>/dev/null || true
    dc restart router 2>/dev/null || true

    # Remove temp files
    rm -f "$FRONTEND_LOG" "$API_LOG"

    echo "Cleanup complete."
}

# Set up trap to run cleanup on exit
trap cleanup EXIT INT TERM

#######################################
# Check prerequisites
#######################################
check_prerequisites() {
    if ! command -v cloudflared &>/dev/null; then
        echo "Error: cloudflared is not installed."
        echo "Install it with: brew install cloudflared"
        exit 1
    fi

    if ! command -v docker &>/dev/null; then
        echo "Error: docker is not installed."
        exit 1
    fi
}


#######################################
# Extract URL from cloudflared log file
# Arguments:
#   $1 - log file path
#   $2 - timeout in seconds
#######################################
extract_url() {
    local log_file=$1
    local timeout=${2:-30}
    local elapsed=0

    while [ $elapsed -lt $timeout ]; do
        # Look for the trycloudflare.com URL in the log
        local url=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$log_file" 2>/dev/null | head -1)
        if [ -n "$url" ]; then
            echo "$url"
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    echo ""
    return 1
}

#######################################
# Apply configuration changes
#######################################
apply_config_changes() {
    local frontend_url=$1
    local api_url=$2

    echo "Applying configuration changes..."

    # 1. amplify-config.ts - Fix process.env -> import.meta.env
    sed -i '' 's/process\.env\./import.meta.env./g' "$AMPLIFY_CONFIG"

    # 2. vite.config.ts - Add allowedHosts inside the existing server block
    if ! grep -q "allowedHosts" "$VITE_CONFIG"; then
        sed -i '' '/host: true,/a\
    allowedHosts: [".trycloudflare.com"],
' "$VITE_CONFIG"
    fi

    # 3. docker-compose.yml - Update VITE_GRAPHQL_URI with API tunnel URL
    # Preserve /graphql path suffix where present
    sed -i '' "s|VITE_GRAPHQL_URI=.*/graphql|VITE_GRAPHQL_URI=$api_url/graphql|" "$DOCKER_COMPOSE"
    sed -i '' "s|VITE_GRAPHQL_URI=http://localhost:4000\$|VITE_GRAPHQL_URI=$api_url|" "$DOCKER_COMPOSE"

    # 3c. Add VITE_DEV_ORIGIN for Vite server to use tunnel URL for script origins
    if ! grep -q "VITE_DEV_ORIGIN" "$DOCKER_COMPOSE"; then
        sed -i '' "s|VITE_COGNITO_SSO_URL_BASE=sso.systest.ledidi.no|VITE_COGNITO_SSO_URL_BASE=sso.systest.ledidi.no\n      - VITE_DEV_ORIGIN=$frontend_url|g" "$DOCKER_COMPOSE"
    fi

    # 3d. Add frontend tunnel URL to ALLOWED_ORIGINS for registries service CORS
    sed -i '' "s|ALLOWED_ORIGINS=http://localhost:3003,http://localhost:3010|ALLOWED_ORIGINS=http://localhost:3003,http://localhost:3010,$frontend_url|" "$DOCKER_COMPOSE"

    # 3b. Worktree compose overlay - also patch VITE_GRAPHQL_URI and ALLOWED_ORIGINS there since it overrides the base
    if [[ -f "$WT_COMPOSE" ]]; then
        WT_COMPOSE_BACKUP=$(mktemp)
        cp "$WT_COMPOSE" "$WT_COMPOSE_BACKUP"
        sed -i '' "s|VITE_GRAPHQL_URI=.*/graphql|VITE_GRAPHQL_URI=$api_url/graphql|" "$WT_COMPOSE"
        sed -i '' "s|VITE_GRAPHQL_URI=http://localhost:4000\$|VITE_GRAPHQL_URI=$api_url|" "$WT_COMPOSE"
        # Patch ALLOWED_ORIGINS to add frontend tunnel URL (handles any port via regex)
        sed -i '' "s|ALLOWED_ORIGINS=http://localhost:[0-9]*,http://localhost:3010|ALLOWED_ORIGINS=http://localhost:$frontend_port,http://localhost:3010,$frontend_url|" "$WT_COMPOSE"
        echo "  Patched worktree compose overlay"
    fi

    # 4. Router CORS origins - add frontend tunnel URL to the base config.
    # The dev script's generate_router_config transforms this into the generated
    # config that's actually mounted. Patching the base means any dev command
    # that regenerates the override will preserve the tunnel URL.
    if ! grep -q "trycloudflare" "$ROUTER_CONFIG"; then
        awk -v url="$frontend_url" '/match_origins:/ { print; print "    - " url; next } { print }' \
            "$ROUTER_CONFIG" > "$ROUTER_CONFIG.tmp" && mv "$ROUTER_CONFIG.tmp" "$ROUTER_CONFIG"
    fi

    echo "Configuration changes applied."
}

#######################################
# Rebuild frontend and restart router
#######################################
rebuild_services() {
    echo ""
    echo "Rebuilding frontend..."
    dc build registries-frontend
    dc up -d registries-frontend

    echo ""
    echo "Recreating registries service (to apply ALLOWED_ORIGINS change)..."
    dc up -d registries

    echo ""
    echo "Restarting router (regenerating config from patched base)..."
    dev restart router

    echo ""
    echo "Waiting for services to be ready..."
    sleep 5
}

#######################################
# Main script
#######################################
main() {
    echo "==================================="
    echo "  Cloudflared Tunnel Setup Script"
    echo "==================================="
    echo ""

    check_prerequisites

    echo "Ports: frontend=$frontend_port, api=$api_port"
    echo ""

    # First, revert any existing changes to ensure clean state
    echo "Ensuring clean config state..."
    git checkout -- "$AMPLIFY_CONFIG" "$VITE_CONFIG" "$DOCKER_COMPOSE" "$ROUTER_CONFIG" 2>/dev/null || true

    echo ""
    echo "Starting tunnels..."
    echo ""

    # Start API tunnel
    echo "Starting API tunnel (port $api_port)..."
    cloudflared tunnel --url "http://localhost:$api_port" 2>"$API_LOG" &
    API_TUNNEL_PID=$!
    echo "API tunnel started (PID: $API_TUNNEL_PID)"

    # Start frontend tunnel
    echo "Starting frontend tunnel (port $frontend_port)..."
    cloudflared tunnel --url "http://localhost:$frontend_port" 2>"$FRONTEND_LOG" &
    FRONTEND_TUNNEL_PID=$!
    echo "Frontend tunnel started (PID: $FRONTEND_TUNNEL_PID)"

    # Wait for and extract URLs
    echo ""
    echo "Waiting for tunnel URLs..."

    API_URL=$(extract_url "$API_LOG" 30)
    if [ -z "$API_URL" ]; then
        echo "Error: Failed to get API tunnel URL"
        exit 1
    fi
    echo "API URL: $API_URL"

    FRONTEND_URL=$(extract_url "$FRONTEND_LOG" 30)
    if [ -z "$FRONTEND_URL" ]; then
        echo "Error: Failed to get frontend tunnel URL"
        exit 1
    fi
    echo "Frontend URL: $FRONTEND_URL"

    echo ""

    # Apply config changes
    apply_config_changes "$FRONTEND_URL" "$API_URL"

    # Rebuild and restart services
    rebuild_services

    # Display final information
    echo ""
    echo "==================================="
    echo "  Tunnels Ready!"
    echo "==================================="
    echo ""
    echo "Frontend: $FRONTEND_URL/en/registries"
    echo "API:      $API_URL"
    echo ""
    echo "Press Ctrl+C to stop tunnels and revert changes."
    echo ""

    # Wait indefinitely
    while true; do
        sleep 1
    done
}

main "$@"
