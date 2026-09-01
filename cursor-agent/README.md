# Cursor Agent CLI config

Version-controlled config for the **Cursor agent CLI** (`cursor-agent`), distinct
from the Cursor GUI editor settings in `../cursor/` (which symlink into
`~/Library/Application Support/Cursor/User/`).

## Files

| File | Live location | How it's linked |
|------|---------------|-----------------|
| `mcp.json` | `~/.cursor/mcp.json` | **symlink** → this repo |
| `statusline.sh` | `~/.cursor/statusline.sh` | **symlink** → this repo |
| `cli-config.json` | `~/.cursor/cli-config.json` | **copy only** (see below) |

### Why `cli-config.json` is not symlinked

Cursor rewrites `~/.cursor/cli-config.json` on every login, injecting auth
material (`authInfo`, `serverConfigCache.authCacheKey`, statsig cache). The copy
here is **sanitized** — auth, server cache, and timestamps removed — so it is
safe to commit but must NOT be symlinked back, or Cursor would write secrets
into the repo.

Treat it as a template documenting the intended settings (permissions, model,
status line, sandbox/approval mode, attribution).

## Restore on a new machine

```bash
# 1. Log in (writes a fresh ~/.cursor/cli-config.json with your auth)
cursor-agent login

# 2. Re-apply the tracked settings on top of the auth'd file, e.g. with jq:
#    merge tracked keys into the live file, preserving authInfo/serverConfigCache.
tmp=$(mktemp)
jq -s '.[0] * .[1]' ~/.cursor/cli-config.json \
  ~/.config/cursor-agent/cli-config.json > "$tmp" && mv "$tmp" ~/.cursor/cli-config.json

# 3. Symlink the no-secret files
ln -sf ~/.config/cursor-agent/mcp.json       ~/.cursor/mcp.json
ln -sf ~/.config/cursor-agent/statusline.sh  ~/.cursor/statusline.sh
chmod +x ~/.config/cursor-agent/statusline.sh

# 4. Skills: the installer links the shared set into ~/.agents/skills, which the
#    Cursor CLI reads — nothing to install by hand.
```

## MCP servers

`mcp.json` mirrors Claude Code and Codex: `chrome-devtools` and `datadog`.
Datadog launches via `../dev/mcp-datadog.sh`, which maps `DD_API_KEY` /
`DD_APP_KEY` (from the gitignored `~/.config/zsh/.zsh_secrets`) to the
`DATADOG_*` vars the MCP server expects — so no secret is committed.

Approve / check servers with:

```bash
cursor-agent mcp list
cursor-agent mcp login datadog   # if auth prompt needed
```
