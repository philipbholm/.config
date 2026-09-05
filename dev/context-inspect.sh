#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/lib/cli.sh"
dev_help_if_requested context "$@"
action=${1:-show}
shift || true
case "$action" in
  show) exec python3 "$SCRIPT_DIR/lib/context-inspect.py" "$action" "$@" ;;
  check)
    [[ $# == 0 ]] || dev_cli_error "use dev context check"
    result=0
    bash "$SCRIPT_DIR/context-render.sh" --check || result=$?
    python3 "$SCRIPT_DIR/lib/context-inspect.py" check || result=$?
    exit "$result"
    ;;
  *) dev_cli_error "use dev context show or dev context check" ;;
esac
