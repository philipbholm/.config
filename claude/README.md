# Claude Config

This directory contains Claude Code configuration files that are version-controlled.

## Structure

- `agents/` - Custom agent definitions
- `hooks/` - Hook scripts that run on Claude events
- `skills/` - Custom skill definitions
- `settings.json` - Claude Code settings

## Setup

Claude Code expects its config at `~/.claude`. To use this setup, create symlinks from `~/.claude` to these files:

```bash
# Create ~/.claude if it doesn't exist
mkdir -p ~/.claude

# Symlink config files
ln -s ~/.config/claude/agents ~/.claude/agents
ln -s ~/.config/claude/hooks ~/.claude/hooks
ln -s ~/.config/claude/skills ~/.claude/skills
ln -s ~/.config/claude/settings.json ~/.claude/settings.json
```

Runtime files (history, cache, projects, etc.) live directly in `~/.claude` and are not version-controlled.
