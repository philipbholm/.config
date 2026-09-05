#!/bin/bash
set -euo pipefail
exec bash "$HOME/.config/dev/dev.sh" agent-config apply --profile work "$@"
