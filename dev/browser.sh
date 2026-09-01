#!/usr/bin/env bash
# Launch the Chromium instance that chrome-devtools-mcp attaches to.
#
# All three agents (Claude Code, Codex, Cursor) point their chrome-devtools MCP
# server at http://127.0.0.1:9222, but nothing else starts a browser there —
# this does. Chrome and Brave 136+ refuse remote debugging on the real default
# profile, so this uses a dedicated --user-data-dir that persists across runs:
# sign in to the dev app once and the session survives every later launch.
#
# Browser: Google Chrome if installed (work machines), otherwise Brave
# (personal). Force one with BROWSER_APP=/path/to/binary.
set -euo pipefail

PORT=9222

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "A debug browser is already listening on :$PORT — leaving it running."
  exit 0
fi

chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
brave="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"

if [[ -n "${BROWSER_APP:-}" ]]; then
  bin="$BROWSER_APP"
  profile="$HOME/.browser-debug-profile"
elif [[ -x "$chrome" ]]; then
  bin="$chrome"
  profile="$HOME/.chrome-debug-profile"
elif [[ -x "$brave" ]]; then
  bin="$brave"
  profile="$HOME/.brave-debug-profile"
else
  echo "Neither Google Chrome nor Brave found in /Applications." >&2
  echo "Install one, or set BROWSER_APP to a Chromium binary." >&2
  exit 1
fi

mkdir -p "$profile"
echo "Launching $(basename "$bin") on :$PORT (profile: $profile)"
nohup "$bin" \
  --remote-debugging-port="$PORT" \
  --user-data-dir="$profile" \
  >/dev/null 2>&1 &
disown
echo "Started (pid $!). Sign in once in this window; the session persists across launches."
