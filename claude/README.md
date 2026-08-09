# Claude Config

This directory contains Claude Code configuration files that are version-controlled.

## Structure

- `agents/` - Custom agent definitions installed on every profile (currently empty)
- `agents.work/` - Custom agent definitions installed only by `install-work.sh`
  (currently empty — the three `ledidi-*` reviewers were removed with the
  `code-review` skill that drove them)
- `skills/` - Custom skill definitions installed on every profile
- `skills.work/` - Custom skill definitions installed only by `install-work.sh`
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
ln -s ~/.config/claude/statusline-command.sh ~/.claude/statusline-command.sh
```

`~/.claude/skills` and `~/.claude/agents` are real directories rather than links, each
holding one symlink per skill/agent — that's what keeps the `.work` sets off personal
machines. `link_claude_dir` links `skills/*` and `agents/*` on both profiles, and
`install-work.sh` calls it again to add `skills.work/*` and `agents.work/*`. It clears
its own previous links on each run, so switching a machine from work to personal
removes the work skills and agents; anything you drop into those directories by hand is
left untouched.

Plugin skills are not linked here at all. `settings.json` enables the plugin
(`mattpocock-skills@claude-plugins-official`, `context7@claude-plugins-official`) and
Claude Code loads its skills from the plugin cache under the plugin's namespace, e.g.
`mattpocock-skills:tdd`. Update them with `/plugin update`, no reinstall needed.

Runtime files (history, cache, projects, etc.) live directly in `~/.claude` and are not version-controlled.
