#!/bin/bash
set -euo pipefail
exec bash "$HOME/.config/dev/dev.sh" worktree destroy "$@"
