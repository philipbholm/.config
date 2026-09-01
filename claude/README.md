# Claude Config

This directory contains Claude Code configuration files that are version-controlled.

## Structure

- `../agents/AGENTS.md` - Harness-neutral global rules linked as `~/.claude/CLAUDE.md`
- `agents/` - Custom agent definitions installed on every profile (currently empty)
- `agents.work/` - Custom agent definitions installed only by `install-work.sh`
  (currently empty — the three `ledidi-*` reviewers were removed with the
  `code-review` skill that drove them)
- (skills moved out) - the shared skill set now lives in the repo's top-level
  `skills/` and `skills.work/`, linked into `~/.claude/skills`; see the root
  `CLAUDE.md`
- `bin/` - Helper executables on PATH (`bb`, `jira`)
- `settings.json` - Claude Code settings (hooks are declared here; the scripts
  themselves live in `dev/`, e.g. `dev/claude-notify.sh`)
- `settings.work.json` - Work-only overlay merged over `settings.json` by
  `dev/sync-agent-configs.sh`: the Datadog MCP server and
  `permissions.defaultMode: "bypassPermissions"`, so work machines start without
  permission prompts (the `deny` list in the base still applies)
- `statusline-command.sh` - Statusline renderer referenced by `settings.json`

## Setup

`install-common.sh` (`link_core`) creates these symlinks; there is nothing to do
by hand. For reference, the links it makes are:

```bash
ln -s ~/.config/claude/settings.json ~/.claude/settings.json
ln -s ~/.config/agents/AGENTS.md ~/.claude/CLAUDE.md
ln -s ~/.config/claude/statusline-command.sh ~/.claude/statusline-command.sh
```

`~/.claude/skills`, `~/.agents/skills`, and `~/.claude/agents` are real directories
rather than links, each holding one symlink per entry — that's what keeps the `.work`
sets off personal machines. `link_entries` links the top-level `skills/*` into both
`~/.claude/skills` (Claude) and `~/.agents/skills` (Codex and Cursor), and `agents/*`
into `~/.claude/agents`, on both profiles; `install-work.sh` calls it again to add
`skills.work/*` and `agents.work/*`. It clears its own previous links on each run, so
switching a machine from work to personal removes the work skills and agents; anything
you drop into those directories by hand is left untouched.

Runtime files (history, cache, projects, etc.) live directly in `~/.claude` and are not version-controlled.
