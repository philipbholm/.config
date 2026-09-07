# Repository Guidelines

## Project Structure & Module Organization

This repository is a macOS dotfiles and workflow repo rooted at `~/.config`. Top-level directories map directly to managed tools: `zsh/`, `tmux/`, `nvim/`, `alacritty/`, `git/`, `cursor/`, `claude/`, and `codex/`; `agents/` holds harness-neutral global guidance, and `skills/` (plus work-only `skills.work/`) holds the shared `SKILL.md` skill set that Claude Code, Codex, and Cursor all load. Development automation lives in `dev/`, including the worktree helpers (`worktree-create.sh`, `worktree-destroy.sh`), Docker stack tooling (`stack.sh`), the debug-browser launcher (`browser-launch-debug.sh`), and the agent notification hooks (`claude-notify.sh`, `codex-notify.sh`, `cursor-notify.sh`). `dev/admin-mock/` is the only standalone TypeScript package in the repo.

## Build, Test, and Development Commands

Use the repo from `~/.config`.

- `./install.sh work|personal` picks a profile and execs `install-<profile>.sh`; both source `install-common.sh`, which installs brew dependencies, creates expected directories, and refreshes symlinks. With no profile the dispatcher only prints usage and exits 1.
- `zsh -lc 'source zsh/.zshrc'` smoke-tests shell config syntax and startup.
- `dev --help` lists the development commands. `dev worktree create <name> <branch> [start-point]` creates a checkout and writes Ledidi agent context. `dev workspace prepare <workspace> ...` prepares named package workspaces; `dev worktree destroy` removes the current worktree and its stack data.
- `dev stack list` shows active dev stacks; `dev stack up` starts the current stack when run inside a supported repo.
- `bash -n dev/<script>.sh` syntax-checks a script without running it; every script in `dev/` is Bash.
- This repo wraps no monorepo lint/build/test runner. The Ledidi monorepo's own `lefthook.yml` gates all six workspaces on commit; for ad-hoc runs, call the underlying commands (`npm run build-ts`, `npx vitest run`, `npx biome check`) from the workspace you changed.
- `cd dev/admin-mock && npm run build` verifies the local TypeScript helper app builds.

## Coding Style & Naming Conventions

Shell scripts are Bash; new ones start with `set -euo pipefail`. Keep functions small, prefer explicit variable names, and preserve existing 2- or 4-space indentation per file. Name scripts in kebab-case, for example `workspace-prepare.sh`. Lua config belongs under `nvim/lua/...`; TypeScript in `dev/admin-mock/src/`.

## Testing Guidelines

There is no single repo-wide test runner. Validate changes with the narrowest relevant command: shell configs via `zsh -lc`, bootstrap changes via `./install.sh <profile>` on a safe machine, `dev/` script changes via `bash -n <script>` plus a targeted run of the affected subcommand, and `dev/admin-mock` changes via `npm run build`. Add small smoke-test steps to documentation when behavior is manual.

## Commit & Pull Request Guidelines

Keep commits focused. PRs should explain the user-facing effect, list any manual setup or migration steps, and include terminal output or screenshots when changing interactive tooling, themes, or editor behavior.

## Security & Configuration Tips

Do not commit secrets or machine-specific auth state. Keep sensitive values in local files like `zsh/.zsh_secrets`, and prefer updating tracked templates, scripts, or docs instead of hardcoding personal paths unless the repo already standardizes them.

## Agent Context

Every change here has to work for all three harnesses: Claude Code, Codex and
Cursor Agent. A rule, skill or script that only one of them can load is
unfinished. When a harness needs its own filename, wiring or syntax, add that
harness's copy in the same change and link it from `install-common.sh`; when a
harness cannot do the thing at all, say so in the file itself rather than
leaving the gap for the next reader to find.

- `agents/AGENTS.md` is the harness-neutral source for global writing and
  workflow rules. The installers link it to each harness's global instruction
  filename: `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, and `~/AGENTS.md` for
  Cursor Agent, which has no file of its own under `~/.cursor` and instead walks
  the workspace's parent directories looking for `AGENTS.md`.
- `skills/` contains shared skills. `skills.work/` contains work-only skills.
- `dev/context/ledidi-monorepo/AGENTS.md` is the single source for Ledidi
  repository context. `dev context render --all-worktrees` renders both `AGENTS.md` and
  `CLAUDE.local.md` into every Ledidi checkout.
- "Update the context" means updating the Ledidi source template and any file
  that the template references.
