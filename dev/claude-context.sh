#!/bin/bash
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
main_repo="${DEV_MAIN_REPO:-$HOME/work/ledidi-monorepo}"

cd "${CLAUDE_PROJECT_DIR:-$PWD}" 2>/dev/null || exit 0
checkout=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
common_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || exit 0
main_repo=$(cd "$main_repo" 2>/dev/null && pwd -P) || exit 0
[[ "$(dirname "$common_dir")" == "$main_repo" ]] || exit 0

bash "$SCRIPT_DIR/context-render.sh" >/dev/null 2>&1 ||
  echo "Warning: dev context render failed, so AGENTS.md below may be stale." >&2

[[ -f "$checkout/AGENTS.md" ]] && cat "$checkout/AGENTS.md"
exit 0
