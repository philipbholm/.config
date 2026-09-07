#!/bin/bash

### This script starts cloudflared tunnels for the frontend and API, layers a
### disposable compose overlay that points the app at the tunnel URLs, and tears
### everything down on exit.
###
### Design note: this script NEVER edits git-tracked files or the dev-generated
### stack overlay. All tunnel config lives in two throwaway files under the
### worktree's stack dir (docker-compose.tunnel.yml + vite.config.tunnel.ts).
### Cleanup just deletes them and recreates the containers, so the worst case is
### a clean stack — stale tunnel URLs can never be left behind, even if a run
### crashes or two runs overlap.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/lib/cli.sh"
dev_help_if_requested stack-expose "$@"
[[ $# -eq 0 ]] || dev_cli_error "dev stack expose takes no arguments"
. "$SCRIPT_DIR/lib/checkout.sh"

# Ensure Docker CLI is in PATH (Docker Desktop on macOS)
[[ -d "/Applications/Docker.app/Contents/Resources/bin" ]] && \
    export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"

if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "Error: Not inside a git repository" >&2
    exit 1
fi
MONOREPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$MONOREPO_ROOT"
PROJECT_NAME="$(dev_checkout_id_for_repo "$MONOREPO_ROOT")"
FRONTEND_BASE_PORT=3003
API_BASE_PORT=4006

# Determine ports + compose project name from worktree slot.
# stack.sh prefixes worktree stacks with wt{slot}- (see where stack.sh sets
# project_name in worktree mode), so the dc() wrapper below must use the same
# name to target the real containers instead of spinning up a duplicate stack
# that collides on the already-allocated ports.
#
# A worktree only gets a slot file once `dev stack up` has run there. Without one we
# must NOT fall back to the base ports — those belong to the main checkout, and
# a tunnel is public, so the fallback would publish someone else's stack to the
# internet. Refuse instead.
worktree_slot_file="$(dev_slot_file_for_repo "$MONOREPO_ROOT")"
if dev_is_worktree_repo "$MONOREPO_ROOT"; then
  if [[ ! -f "$worktree_slot_file" ]]; then
    echo "Error: this worktree has no dev stack slot." >&2
    echo "Expected: $worktree_slot_file" >&2
    echo "Run 'dev stack up' here first. Tunneling without a slot would expose the main" >&2
    echo "checkout's ports ($FRONTEND_BASE_PORT/$API_BASE_PORT) to the public internet." >&2
    exit 1
  fi
  slot="$(tr -d '[:space:]' < "$worktree_slot_file")"
  # Worktree slots are 1-9; a 0 or a garbled file would resolve to base ports.
  if [[ ! "$slot" =~ ^[1-9]$ ]]; then
    echo "Error: unusable slot '$slot' in $worktree_slot_file (expected 1-9)." >&2
    echo "Run 'dev stack up' here to reassign it." >&2
    exit 1
  fi
  offset=$((slot * 100))
  frontend_port=$((FRONTEND_BASE_PORT + offset))
  api_port=$((API_BASE_PORT + offset))
  PROJECT_NAME="wt${slot}-${PROJECT_NAME}"
else
  frontend_port=$FRONTEND_BASE_PORT
  api_port=$API_BASE_PORT
fi

# Source vite config (read-only — copied, never edited)
VITE_CONFIG="$MONOREPO_ROOT/apps/registries-frontend/vite.config.ts"

# Worktree stack dir + files.
#   WT_COMPOSE       : the dev-generated stack overlay (read-only here)
#   TUNNEL_COMPOSE   : our disposable overlay with the tunnel deltas
#   TUNNEL_VITE_CONFIG: a patched copy of vite.config.ts mounted into the container
TMP_BASE="$(dev_stack_dir_for_repo "$MONOREPO_ROOT")"
WT_COMPOSE="$TMP_BASE/docker-compose.stack.yml"
TUNNEL_COMPOSE="$TMP_BASE/docker-compose.tunnel.yml"
TUNNEL_VITE_CONFIG="$TMP_BASE/vite.config.tunnel.ts"

# docker compose wrapper: layer base + dev stack overlay + (when present) the
# tunnel overlay. Removing TUNNEL_COMPOSE and recreating yields a clean stack.
dc() {
  local -a files=(-f "$MONOREPO_ROOT/docker-compose.yml")
  [[ -f "$WT_COMPOSE" ]] && files+=(-f "$WT_COMPOSE")
  [[ -f "$TUNNEL_COMPOSE" ]] && files+=(-f "$TUNNEL_COMPOSE")
  COMPOSE_PROJECT_NAME="$PROJECT_NAME" docker compose "${files[@]}" "$@"
}

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
# Kill any cloudflared tunnels pointed at this worktree's ports. Targets the
# exact --url so it never touches tunnels for other worktrees.
#######################################
kill_stale_tunnels() {
    pkill -f "cloudflared tunnel --url http://localhost:$frontend_port" 2>/dev/null || true
    pkill -f "cloudflared tunnel --url http://localhost:$api_port" 2>/dev/null || true
}

#######################################
# Cleanup function - runs on script exit
#######################################
cleanup() {
    echo ""
    echo "Cleaning up..."

    # Kill our tunnel processes (and any stragglers on our ports)
    if [ -n "$FRONTEND_TUNNEL_PID" ] && kill -0 "$FRONTEND_TUNNEL_PID" 2>/dev/null; then
        echo "Stopping frontend tunnel (PID: $FRONTEND_TUNNEL_PID)..."
        kill "$FRONTEND_TUNNEL_PID" 2>/dev/null || true
    fi
    if [ -n "$API_TUNNEL_PID" ] && kill -0 "$API_TUNNEL_PID" 2>/dev/null; then
        echo "Stopping API tunnel (PID: $API_TUNNEL_PID)..."
        kill "$API_TUNNEL_PID" 2>/dev/null || true
    fi
    kill_stale_tunnels

    # Drop the tunnel overlay + patched config copy, then recreate the two
    # affected services so they fall back to the clean stack config.
    echo "Removing tunnel overlay and recreating services with clean config..."
    rm -f "$TUNNEL_COMPOSE" "$TUNNEL_VITE_CONFIG"
    dc up -d --force-recreate registries-frontend 2>/dev/null || true
    dc up -d --force-recreate registries 2>/dev/null || true

    rm -f "$FRONTEND_LOG" "$API_LOG"

    echo "Cleanup complete."
}

# Run cleanup once on exit; INT/TERM trigger an exit (which fires the EXIT trap)
# rather than running cleanup inline, otherwise the handler returns and the main
# `while true` loop resumes, leaving the script running after Ctrl+C.
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

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
        # Match the quick-tunnel URL, whose subdomain is always multi-word and
        # hyphenated (e.g. neat-brave-otter-cloud). The `(-[a-z0-9]+)+` requires
        # at least one hyphen so we skip cloudflared's own `api.trycloudflare.com`
        # log references, which would otherwise match first.
        local url=$(grep -Eo 'https://[a-z0-9]+(-[a-z0-9]+)+\.trycloudflare\.com' "$log_file" 2>/dev/null | head -1)
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
# Generate the patched vite.config copy + the tunnel compose overlay.
# Nothing here mutates a git-tracked file or the dev stack overlay.
#######################################
generate_tunnel_overlay() {
    local frontend_url=$1
    local api_url=$2

    echo "Generating tunnel overlay..."

    # The stack dir exists whenever a dev stack has been generated; create it
    # anyway so a first run in the main checkout can't die on the redirect below.
    mkdir -p "$TMP_BASE"

    # Patched vite.config.ts copy (mounted over the image's baked-in one):
    #   - allowedHosts so Vite's dev-server host check accepts *.trycloudflare.com
    #   - a process.env shim so amplify-config.ts's non-localhost branch
    #     (process.env.VITE_APP_BASE_DOMAIN) doesn't throw "process is not
    #     defined" in the browser when served from the tunnel host.
    cp "$VITE_CONFIG" "$TUNNEL_VITE_CONFIG"
    sed -i '' '/host: true,/a\
    allowedHosts: [".trycloudflare.com"],
' "$TUNNEL_VITE_CONFIG"
    sed -i '' 's|base: command === "build" ? "/registries/" : "/",|&\
  define: { "process.env.VITE_APP_BASE_DOMAIN": "undefined" },|' "$TUNNEL_VITE_CONFIG"

    # Tunnel compose overlay: point the frontend at the tunnel URLs, mount the
    # patched vite config, and allow the frontend tunnel origin through CORS.
    cat > "$TUNNEL_COMPOSE" <<YAML
# Auto-generated by tunnel.sh — disposable. Removed on exit.
services:
  registries-frontend:
    environment:
      - VITE_APP_URL=$frontend_url
      - VITE_GRAPHQL_URI=$api_url/graphql
      - VITE_GRAPHQL_PROM_URI=$api_url/graphql-prom
      - VITE_REGISTRIES_API_URL=$api_url
    volumes:
      - $TUNNEL_VITE_CONFIG:/apps/registries-frontend/vite.config.ts:cached

  registries:
    environment:
      - ALLOWED_ORIGINS=http://localhost:$frontend_port,http://localhost:3010,$frontend_url
YAML

    echo "Tunnel overlay generated."
}

#######################################
# Poll the registries API until it serves a CORS preflight that echoes the
# frontend tunnel origin. This proves the Node app has booted AND registered
# CORS with the new ALLOWED_ORIGINS, so the frontend's first GraphQL request
# won't race the API and leave the SPA stuck on "An unknown error occurred".
# Arguments:
#   $1 - timeout in seconds (default 90)
#######################################
wait_for_api() {
    local timeout=${1:-90}
    local elapsed=0

    echo "Waiting for registries API + CORS to be ready (origin $FRONTEND_URL)..."
    while [ $elapsed -lt $timeout ]; do
        if curl -sS -i -m 3 -X OPTIONS "http://localhost:$api_port/graphql" \
              -H "Origin: $FRONTEND_URL" \
              -H "Access-Control-Request-Method: POST" \
              -H "Access-Control-Request-Headers: content-type" 2>/dev/null \
              | grep -qi "^access-control-allow-origin: $FRONTEND_URL"; then
            echo "Registries API ready (CORS verified)."
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    echo "Warning: registries API not ready after ${timeout}s — the site may show" >&2
    echo "a transient error on first load until the API finishes booting. Reload." >&2
    return 1
}

#######################################
# Recreate registries and frontend to pick up the tunnel overlay.
#
# Order matters: recreate registries FIRST and wait until its API + CORS are
# actually serving, THEN recreate the frontend. Otherwise the frontend can be
# reachable before the API is ready, and the first GraphQL calls fail CORS —
# which the SPA surfaces as a sticky "An unknown error occurred" until reload.
#######################################
recreate_services() {
    echo ""
    echo "Recreating registries service first (to apply ALLOWED_ORIGINS change)..."
    dc up -d --force-recreate registries

    echo ""
    # `|| true`: a timeout is a warning, not a failure — set -e would otherwise
    # abort the run (and tear the stack down) instead of letting the user reload.
    wait_for_api 90 || true

    echo ""
    echo "Recreating frontend (tunnel env + patched vite.config, no image rebuild)..."
    dc up -d --force-recreate registries-frontend

    echo ""
    echo "Waiting for the frontend dev server to serve..."
    local elapsed=0
    while [ $elapsed -lt 60 ]; do
        if curl -sS -o /dev/null -m 3 "http://localhost:$frontend_port/" 2>/dev/null; then
            echo "Frontend dev server ready."
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
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

    # A non-interactive caller stays blocked for the whole run, so say so before
    # the minutes of setup rather than after.
    if [[ ! -t 1 ]]; then
        echo "Note: this stays in the foreground until stopped, and the tunnel URLs are"
        echo "printed only once the stack is ready. Non-interactive callers should run it"
        echo "as a background job and read its output rather than waiting on it."
        echo ""
    fi

    # Clean baseline: kill any tunnels already bound to our ports and drop any
    # leftover overlay from a previous run that didn't clean up. This makes
    # re-runs and recovery-after-crash safe.
    echo "Ensuring clean baseline..."
    kill_stale_tunnels
    rm -f "$TUNNEL_COMPOSE" "$TUNNEL_VITE_CONFIG"

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

    # `|| true` so the timeout path reaches the message below instead of set -e
    # aborting the script on the failing assignment.
    API_URL=$(extract_url "$API_LOG" 30) || true
    if [ -z "$API_URL" ]; then
        echo "Error: Failed to get API tunnel URL. cloudflared log:" >&2
        cat "$API_LOG" >&2
        exit 1
    fi
    echo "API URL: $API_URL"

    FRONTEND_URL=$(extract_url "$FRONTEND_LOG" 30) || true
    if [ -z "$FRONTEND_URL" ]; then
        echo "Error: Failed to get frontend tunnel URL. cloudflared log:" >&2
        cat "$FRONTEND_LOG" >&2
        exit 1
    fi
    echo "Frontend URL: $FRONTEND_URL"

    echo ""

    # Generate overlay + recreate services
    generate_tunnel_overlay "$FRONTEND_URL" "$API_URL"
    recreate_services

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

    # Park until interrupted, but bail out if either cloudflared dies: exiting
    # fires the EXIT trap, so a dead tunnel drops the overlay instead of leaving
    # a URL advertised as ready that no longer resolves.
    while true; do
        if ! kill -0 "$API_TUNNEL_PID" 2>/dev/null; then
            echo "API tunnel exited (PID $API_TUNNEL_PID). Stopping." >&2
            exit 1
        fi
        if ! kill -0 "$FRONTEND_TUNNEL_PID" 2>/dev/null; then
            echo "Frontend tunnel exited (PID $FRONTEND_TUNNEL_PID). Stopping." >&2
            exit 1
        fi
        sleep 1
    done
}

main "$@"
