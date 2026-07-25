# Claude Config

This directory contains Claude Code configuration files that are version-controlled.

## Structure

- `agents/` - Custom agent definitions
- `skills/` - Custom skill definitions
- `bin/` - Helper executables on PATH (`bb`, `jira`)
- `settings.json` - Claude Code settings (hooks are declared here; the scripts
  themselves live in `dev/`, e.g. `dev/claude-notify.sh`)
- `statusline-command.sh` - Statusline renderer referenced by `settings.json`

## Setup

`install-common.sh` (`link_core`) creates these symlinks; there is nothing to do
by hand. For reference, the links it makes are:

```bash
ln -s ~/.config/claude/agents ~/.claude/agents
ln -s ~/.config/claude/skills ~/.claude/skills
ln -s ~/.config/claude/settings.json ~/.claude/settings.json
ln -s ~/.config/claude/statusline-command.sh ~/.claude/statusline-command.sh
```

Runtime files (history, cache, projects, etc.) live directly in `~/.claude` and are not version-controlled.
