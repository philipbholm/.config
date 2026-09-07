# Codex Config

This directory contains Codex configuration files that are version-controlled.

## Structure

- `config.toml` - Codex settings
- `~/.codex/AGENTS.md` - Symlink to the shared global rules in `agents/AGENTS.md`
- `rules/default.rules` - Shell prefix-rule allowlist

Codex has no skills dir of its own here — it reads the shared skill set from
`~/.agents/skills` (see the repo's top-level `skills/`).

## Setup

Handled by `install.sh`; there is nothing to copy by hand.

`config.toml`, `AGENTS.md`, and `rules/default.rules` are symlinked, so they sync
automatically. Skills are the shared set in the repo's top-level `skills/` and
`skills.work/`, linked into `~/.agents/skills` — the harness-neutral location Codex
reads and symlink-follows (verified on the installed Codex; if a future version stops
following the links, switch `link_entries` to an rsync copy into that dir). Codex's own
bundled skills live in `~/.codex/skills/.system` and are intentionally not
version-controlled here.

Runtime files (history, logs, state DBs, sessions, auth, cache, etc.) stay in `~/.codex` and are not version-controlled.
