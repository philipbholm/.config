#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$SCRIPT_DIR/lib/cli.sh"
. "$SCRIPT_DIR/lib/checkout.sh"
dev_help_if_requested test "$@"

suite=test:e2e
if [[ "${1:-}" == --shell ]]; then
    suite=test:e2e:shell
    shift
fi
if [[ $# -gt 0 ]]; then
    [[ "$1" == -- ]] || dev_cli_error "use dev test e2e [--shell] -- [Playwright arguments]"
    shift
fi

repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || dev_cli_error "not inside a Git checkout"
workspace="$repo_root/apps/registries-frontend"
[[ -f "$workspace/playwright.config.ts" ]] || dev_cli_error "this checkout has no registries Playwright configuration"
[[ "$suite" != test:e2e:shell || -f "$workspace/playwright.shell.config.ts" ]] || dev_cli_error "this checkout has no shell Playwright configuration"

cd "$repo_root"
bash "$SCRIPT_DIR/stack.sh" up registries codelist -d
slot=$(dev_slot_for_repo "$repo_root")
[[ "$slot" =~ ^[0-9]$ ]] || dev_cli_error "invalid stack slot"
if dev_is_worktree_repo "$repo_root" && [[ "$slot" == 0 ]]; then
    dev_cli_error "this worktree has no assigned stack slot"
fi
offset=$(( slot * 100 ))
export VITE_REGISTRIES_API_URL="http://localhost:$(( DEV_REGISTRIES_BASE_PORT + offset ))"
export E2E_API_URL="$VITE_REGISTRIES_API_URL/graphql"
export REGISTRIES_BASE_URL="http://localhost:$(( DEV_FRONTEND_BASE_PORT + 1 + offset ))"
export FRONTEND_BASE_URL="$REGISTRIES_BASE_URL"
if [[ "$suite" == test:e2e:shell ]]; then
    export FRONTEND_BASE_URL="http://localhost:$(( 3010 + offset ))"
fi
export PLAYWRIGHT_HTML_OPEN=never

python3 "$SCRIPT_DIR/lib/e2e-preflight.py"
echo "E2E frontend: $FRONTEND_BASE_URL"
echo "E2E API: $E2E_API_URL"
cd "$workspace"
exec npm run "$suite" -- "$@"
