#!/usr/bin/env bash
# Regenerate work agent configs by merging the clean base configs with the
# work-only overlays (Datadog MCP, Claude's bypassPermissions default, Codex
# work project trusts).
#
# Writes REAL files (replacing the personal symlinks) so the work bits are
# never written back through a symlink into the repo. Run on work machines
# after editing any base or overlay agent config.
set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.config}"

echo "Generating work agent configs..."

# Claude — deep-merge JSON (base * overlay merges mcpServers recursively)
rm -f "$HOME/.claude/settings.json"
jq -s '.[0] * .[1]' \
  "$DOTFILES/claude/settings.json" \
  "$DOTFILES/claude/settings.work.json" \
  > "$HOME/.claude/settings.json"

# Cursor agent — deep-merge JSON
rm -f "$HOME/.cursor/mcp.json"
jq -s '.[0] * .[1]' \
  "$DOTFILES/cursor-agent/mcp.json" \
  "$DOTFILES/cursor-agent/mcp.work.json" \
  > "$HOME/.cursor/mcp.json"

# Codex — independent TOML tables, safe to concatenate (blank line separator)
rm -f "$HOME/.codex/config.toml"
{
  cat "$DOTFILES/codex/config.toml"
  echo
  cat "$DOTFILES/codex/config.work.toml"
} > "$HOME/.codex/config.toml"

echo "Regenerated:"
echo "  ~/.claude/settings.json"
echo "  ~/.cursor/mcp.json"
echo "  ~/.codex/config.toml"
