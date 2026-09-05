#!/bin/bash
set -euo pipefail

script_path=${BASH_SOURCE[0]}
while [[ -L "$script_path" ]]; do
    script_parent=$(cd "$(dirname "$script_path")" && pwd)
    script_path=$(readlink "$script_path")
    [[ "$script_path" == /* ]] || script_path="$script_parent/$script_path"
done
SCRIPT_DIR=$(cd "$(dirname "$script_path")" && pwd)
. "$SCRIPT_DIR/lib/cli.sh"

if [[ $# -eq 0 ]]; then
    dev_help dev
    exit 0
fi

case "$1" in
    --help|-h|help) dev_help "${2:-dev}"; exit 0 ;;
    up|down|logs|exec|ps|build|stop|restart|config|pull|images|top|events|port|run)
        exec bash "$SCRIPT_DIR/stack.sh" "$@" ;;
    start) shift; exec bash "$SCRIPT_DIR/stack.sh" up "$@" ;;
    nuke) shift; exec bash "$SCRIPT_DIR/stack.sh" destroy "$@" ;;
    status) shift; exec bash "$SCRIPT_DIR/stack.sh" list "$@" ;;
esac

subject=$1
shift
case "$subject" in
    worktree|workspace|stack|context|session|agent-config|browser) ;;
    *) dev_cli_error "unknown command group: $subject" ;;
esac
if [[ $# -eq 0 || "$1" == --help || "$1" == -h || "$1" == help ]]; then
    dev_help "$subject"
    exit 0
fi
action=$1
shift
case "$subject $action" in
    'worktree create') script=worktree-create ;;
    'worktree destroy') script=worktree-destroy ;;
    'workspace prepare') script=workspace-prepare ;;
    'stack expose') script=stack-expose ;;
    'stack '*) exec bash "$SCRIPT_DIR/stack.sh" "$action" "$@" ;;
    'context render') script=context-render ;;
    'context show'|'context check') exec bash "$SCRIPT_DIR/context-inspect.sh" "$action" "$@" ;;
    'session search') script=session-search ;;
    'agent-config apply') script=agent-config-apply ;;
    'browser launch-debug') script=browser-launch-debug ;;
    *) dev_cli_error "unknown command: $subject $action" ;;
esac
exec bash "$SCRIPT_DIR/$script.sh" "$@"
