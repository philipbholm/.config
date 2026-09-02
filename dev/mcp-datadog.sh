#!/usr/bin/env bash
# Datadog MCP server launcher, shared by Claude Code, Codex, and Cursor.
#
# Keeps Datadog secret handling in one place: the @winor30/mcp-server-datadog
# package expects DATADOG_API_KEY / DATADOG_APP_KEY, but our credentials live in
# ~/.config/zsh/.zsh_secrets as DD_API_KEY / DD_APP_KEY. GUI apps do not inherit
# the interactive shell environment, so this wrapper loads only those two
# assignments when needed. No secret lands in a version-controlled config file.
#
# Each agent points its "datadog" MCP server at this script as the command.
set -euo pipefail

SECRETS_FILE="${DATADOG_SECRETS_FILE:-$HOME/.config/zsh/.zsh_secrets}"

load_secret() {
  local name="$1"
  local assignment
  local value

  [[ -n "${!name:-}" ]] && return 0
  [[ -r "$SECRETS_FILE" ]] || return 0

  while IFS= read -r assignment; do
    case "$assignment" in
      "export $name="*)
        value="${assignment#*=}"
        if [[ "$value" == \"*\" && "$value" == *\" ]] ||
          [[ "$value" == \'*\' && "$value" == *\' ]]; then
          value="${value:1:${#value}-2}"
        fi
        printf -v "$name" '%s' "$value"
        export "$name"
        return 0
        ;;
    esac
  done < "$SECRETS_FILE"
}

load_secret DD_API_KEY
load_secret DD_APP_KEY

exec env \
  DATADOG_API_KEY="${DD_API_KEY:?DD_API_KEY not set (source ~/.config/zsh/.zsh_secrets)}" \
  DATADOG_APP_KEY="${DD_APP_KEY:?DD_APP_KEY not set (source ~/.config/zsh/.zsh_secrets)}" \
  DATADOG_SITE="${DATADOG_SITE:-datadoghq.eu}" \
  npx -y @winor30/mcp-server-datadog
