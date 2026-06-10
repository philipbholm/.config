#!/usr/bin/env bash
# Datadog MCP server launcher, shared by Claude Code, Codex, and Cursor.
#
# Keeps Datadog secret handling in one place: the @winor30/mcp-server-datadog
# package expects DATADOG_API_KEY / DATADOG_APP_KEY, but our credentials live in
# the shell as DD_API_KEY / DD_APP_KEY (sourced from ~/.config/zsh/.zsh_secrets,
# which is gitignored). This wrapper maps the former to the latter so no secret
# ever lands in a version-controlled config file.
#
# Each agent points its "datadog" MCP server at this script as the command.
set -euo pipefail

exec env \
  DATADOG_API_KEY="${DD_API_KEY:?DD_API_KEY not set (source ~/.config/zsh/.zsh_secrets)}" \
  DATADOG_APP_KEY="${DD_APP_KEY:?DD_APP_KEY not set (source ~/.config/zsh/.zsh_secrets)}" \
  DATADOG_SITE="${DATADOG_SITE:-datadoghq.eu}" \
  npx -y @winor30/mcp-server-datadog
