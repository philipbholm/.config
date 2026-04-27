# Codex Config

This directory contains Codex configuration files that are version-controlled.

## Structure

- `config.toml` - Codex settings
- `rules/default.rules` - Shell prefix-rule allowlist
- `skills/code-review/` - Multi-agent review skill

## Setup

Handled by `install.sh`. Re-run after pulling skill changes to push them into `~/.codex`:

```bash
rsync -a --delete ~/.config/codex/skills/code-review/ ~/.codex/skills/code-review/
```

`config.toml` and `rules/default.rules` are symlinked, so they sync automatically. Skills are copied because Codex's skill loader doesn't follow symlinked skill dirs reliably.

System-managed skills live in `~/.codex/skills/.system` and are intentionally not version-controlled here.

Runtime files (history, logs, state DBs, sessions, auth, cache, etc.) stay in `~/.codex` and are not version-controlled.
