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

## Terminal contrast after a theme change

`switch-theme.sh` waits for Alacritty to load the theme, then queries each local
Alacritty client attached to the default tmux server. This refreshes the colors
tmux reports to applications. Named tmux servers and remote clients are outside
this script's scope.

Codex CLI 0.153.4 also caches terminal colors at startup. A running Codex session
can therefore keep pale input and user-message backgrounds after the terminal
switches to dark mode. Exit Codex when its work is finished, then run
`codex resume` and select the same conversation. Restarting Codex is still needed
after each terminal theme change; refreshing tmux fixes color detection for the
next Codex process.

To smoke-test a theme switch, run `./switch-theme.sh light` from this repo, start
Codex inside tmux, and check that input and user messages are readable. Exit
Codex, run `./switch-theme.sh dark`, and repeat. Finish on your preferred theme.
