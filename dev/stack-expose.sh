#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/lib/cli.sh"
dev_help_if_requested stack-expose "$@"
[[ $# -eq 0 ]] || dev_cli_error "dev stack expose takes no arguments"
. "$SCRIPT_DIR/lib/checkout.sh"

if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "Error: Not inside a git repository" >&2
    exit 1
fi
MONOREPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$MONOREPO_ROOT"
FRONTEND_BASE_PORT=3003
API_BASE_PORT=4006

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
else
  frontend_port=$FRONTEND_BASE_PORT
  api_port=$API_BASE_PORT
fi

TMP_BASE="$(dev_stack_dir_for_repo "$MONOREPO_ROOT")"
OVERRIDES="$TMP_BASE/overrides.json"
TUNNEL_VITE_CONFIG_NAME="vite.config.tunnel.ts"
TUNNEL_VITE_CONFIG="$MONOREPO_ROOT/apps/registries-frontend/$TUNNEL_VITE_CONFIG_NAME"

stack() {
  python3 -B "$SCRIPT_DIR/lib/stack.py" "$@"
}

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

    echo "Removing tunnel overrides and restarting services with clean config..."
    rm -f "$OVERRIDES" "$TUNNEL_VITE_CONFIG"
    stack restart registries registries-frontend || true

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

    if [[ ! -f "$TMP_BASE/pids/registries.json" || ! -f "$TMP_BASE/pids/registries-frontend.json" ]]; then
        echo "Error: this checkout's registries and frontend are not running. Run 'dev stack up' first."
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

generate_tunnel_overlay() {
    local frontend_url=$1
    local api_url=$2

    echo "Generating tunnel overrides..."

    mkdir -p "$TMP_BASE"
    exclude_file="$(git -C "$MONOREPO_ROOT" rev-parse --path-format=absolute --git-path info/exclude)"
    grep -qxF "/apps/registries-frontend/$TUNNEL_VITE_CONFIG_NAME" "$exclude_file" 2>/dev/null ||
        printf '/apps/registries-frontend/%s\n' "$TUNNEL_VITE_CONFIG_NAME" >> "$exclude_file"

    cat > "$TUNNEL_VITE_CONFIG" <<'TS'
import baseConfig from "./vite.config";

export default async (env) => {
  const config = typeof baseConfig === "function" ? await baseConfig(env) : baseConfig;
  return {
    ...config,
    define: { ...config.define, "process.env.VITE_APP_BASE_DOMAIN": "undefined" },
    server: { ...config.server, allowedHosts: [".trycloudflare.com"] },
  };
};
TS

    FRONTEND_PORT="$frontend_port" FRONTEND_URL="$frontend_url" API_URL="$api_url" \
        CONFIG_NAME="$TUNNEL_VITE_CONFIG_NAME" python3 -c '
import json, os, sys
api = os.environ["API_URL"]
json.dump({
    "registries-frontend": {
        "env": {
            "VITE_APP_URL": os.environ["FRONTEND_URL"],
            "VITE_GRAPHQL_URI": f"{api}/graphql",
            "VITE_GRAPHQL_PROM_URI": f"{api}/graphql-prom",
            "VITE_REGISTRIES_API_URL": api,
        },
        "vite_config": os.environ["CONFIG_NAME"],
    },
    "registries": {
        "env": {
            "ALLOWED_ORIGINS": f"http://localhost:{os.environ[\"FRONTEND_PORT\"]},http://localhost:3010,{os.environ[\"FRONTEND_URL\"]}",
        },
    },
}, sys.stdout, indent=2)
' > "$OVERRIDES"

    echo "Tunnel overrides generated."
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
# Order matters: restart registries FIRST and wait until its API + CORS are
# actually serving, THEN restart the frontend. Otherwise the frontend can be
# reachable before the API is ready, and the first GraphQL calls fail CORS —
# which the SPA surfaces as a sticky "An unknown error occurred" until reload.
#######################################
recreate_services() {
    echo ""
    echo "Restarting registries first (to apply ALLOWED_ORIGINS change)..."
    stack restart registries

    echo ""
    wait_for_api 90 || true

    echo ""
    echo "Restarting the frontend with the tunnel URLs and Vite config..."
    stack restart registries-frontend
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
    rm -f "$OVERRIDES" "$TUNNEL_VITE_CONFIG"

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
