#!/bin/bash
set -euo pipefail

opencode_dir="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
claude_config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}"
managed_global_rules="${CLAUDE_GLOBAL_RULES_FILE:-$HOME/.config/CLAUDE.md}"

mkdir -p "$opencode_dir"

ensure_symlink() {
  local src="$1"
  local dst="$2"

  if [ ! -e "$src" ]; then
    echo "Skipping missing source: $src"
    return
  fi

  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "Skipping existing non-symlink: $dst"
    return
  fi

  ln -sfn "$src" "$dst"
  echo "Linked $dst -> $src"
}

ensure_symlink "$managed_global_rules" "$opencode_dir/AGENTS.md"
ensure_symlink "$claude_config_dir/skills" "$opencode_dir/skills"

echo "OpenCode symlink setup complete."
