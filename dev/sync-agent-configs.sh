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

# Generate a config beside its destination and rename it into place, so a failed
# merge leaves the live file untouched instead of truncating it. Whatever the
# live file had that the merge drops (keys an agent or /config wrote at runtime)
# is shown as a diff and kept in a .bak next to it.
generate() {
  local dest="$1"
  shift
  local tmp
  tmp=$(mktemp "$dest.XXXXXX")

  if ! "$@" > "$tmp" || [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    echo "Error: could not generate $dest — left the existing file in place" >&2
    exit 1
  fi
  chmod 644 "$tmp"  # mktemp creates 0600; these are ordinary config files

  if [[ -f "$dest" && ! -L "$dest" ]] && ! cmp -s "$dest" "$tmp"; then
    cp "$dest" "$dest.bak"
    echo "  ${dest/#$HOME/~} changed (previous copy kept as ${dest##*/}.bak):"
    diff -u -L current -L generated "$dest" "$tmp" | sed 's/^/    /' || true
  fi

  mv "$tmp" "$dest"
}

# Deep-merge JSON (base * overlay merges mcpServers recursively)
merge_json() {
  jq -s '.[0] * .[1]' "$1" "$2"
}

# Independent TOML tables, safe to concatenate (blank line separator)
concat_toml() {
  cat "$1" && echo && cat "$2"
}

echo "Generating work agent configs..."

# Claude
generate "$HOME/.claude/settings.json" merge_json \
  "$DOTFILES/claude/settings.json" \
  "$DOTFILES/claude/settings.work.json"

# Cursor agent
generate "$HOME/.cursor/mcp.json" merge_json \
  "$DOTFILES/cursor-agent/mcp.json" \
  "$DOTFILES/cursor-agent/mcp.work.json"

# Codex
generate "$HOME/.codex/config.toml" concat_toml \
  "$DOTFILES/codex/config.toml" \
  "$DOTFILES/codex/config.work.toml"

echo "Regenerated:"
echo "  ~/.claude/settings.json"
echo "  ~/.cursor/mcp.json"
echo "  ~/.codex/config.toml"
