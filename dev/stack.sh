#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/lib/cli.sh"
dev_help_if_requested stack "$@"
if [[ $# -eq 0 ]]; then
    dev_help stack
    exit 0
fi
case "$1" in
    up|down|stop|destroy|list|ps|logs|restart|psql|reap) ;;
    *) dev_cli_error "unknown stack action: $1" ;;
esac
if [[ "$1" == list && $# -gt 1 ]]; then
    dev_cli_error "dev stack list takes no arguments"
fi
if [[ "$1" == destroy && $# -gt 1 && ( $# -ne 2 || "$2" != --yes ) ]]; then
    dev_cli_error "use dev stack destroy [--yes]"
fi

exec python3 -B "$SCRIPT_DIR/lib/stack.py" "$@"
