# Codex Config

This directory contains Codex configuration files that are version-controlled.

## Structure

- `config.toml` - Codex settings
- `rules/default.rules` - Shell prefix-rule allowlist
- `skills/simple-review/` - Custom skill copied from Claude config

## Setup

Codex expects config at `~/.codex`. To use this setup, symlink these files:

```bash
mkdir -p ~/.codex/rules ~/.codex/skills

ln -sfn ~/.config/codex/config.toml ~/.codex/config.toml
ln -sfn ~/.config/codex/rules/default.rules ~/.codex/rules/default.rules
ln -sfn ~/.config/codex/skills/simple-review ~/.codex/skills/simple-review
```

System-managed skills remain in `~/.codex/skills/.system` and are intentionally not version-controlled here.

Runtime files (history, logs, state DBs, sessions, auth, cache, etc.) stay in `~/.codex` and are not version-controlled.
