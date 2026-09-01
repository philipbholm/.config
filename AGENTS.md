# Repository Guidelines

## Project Structure & Module Organization

This repository is a macOS dotfiles and workflow repo rooted at `~/.config`. Top-level directories map directly to managed tools: `zsh/`, `tmux/`, `nvim/`, `alacritty/`, `git/`, `cursor/`, `claude/`, and `codex/`; `agents/` holds harness-neutral global guidance, and `skills/` (plus work-only `skills.work/`) holds the shared `SKILL.md` skill set that Claude Code, Codex, and Cursor all load. Development automation lives in `dev/`, including the worktree helpers (`wt-up.sh`, `wt-down.sh`), Docker stack tooling (`dev.sh`), the debug-browser launcher (`browser.sh`), and the agent notification hooks (`claude-notify.sh`, `codex-notify.sh`). `dev/admin-mock/` is the only standalone TypeScript package in the repo.

## Build, Test, and Development Commands

Use the repo from `~/.config`.

- `./install.sh work|personal` picks a profile and execs `install-<profile>.sh`; both source `install-common.sh`, which installs brew dependencies, creates expected directories, and refreshes symlinks. With no profile the dispatcher only prints usage and exits 1.
- `zsh -lc 'source zsh/.zshrc'` smoke-tests shell config syntax and startup.
- `bash dev/wt-up.sh <name> <branch> [start-point]` creates a harness-agnostic worktree under `<repo>/.worktrees/`; `bash dev/setup-stack.sh` bootstraps it and `bash dev/wt-down.sh` tears it down.
- `bash dev/dev.sh status` shows active dev stacks; `bash dev/dev.sh up` starts the current stack when run inside a supported repo.
- `bash -n dev/<script>.sh` syntax-checks a script without running it; every script in `dev/` is Bash.
- This repo wraps no monorepo lint/build/test runner. The Ledidi monorepo's own `lefthook.yml` gates all six workspaces on commit; for ad-hoc runs, call the underlying commands (`npm run build-ts`, `npx vitest run`, `npx biome check`) from the workspace you changed.
- `cd dev/admin-mock && npm run build` verifies the local TypeScript helper app builds.

## Coding Style & Naming Conventions

Shell scripts are Bash; new ones start with `set -euo pipefail`. Keep functions small, prefer explicit variable names, and preserve existing 2- or 4-space indentation per file. Name scripts in kebab-case, for example `setup-stack.sh`. Lua config belongs under `nvim/lua/...`; TypeScript in `dev/admin-mock/src/`.

## Testing Guidelines

There is no single repo-wide test runner. Validate changes with the narrowest relevant command: shell configs via `zsh -lc`, bootstrap changes via `./install.sh <profile>` on a safe machine, `dev/` script changes via `bash -n <script>` plus a targeted run of the affected subcommand, and `dev/admin-mock` changes via `npm run build`. Add small smoke-test steps to documentation when behavior is manual.

## Commit & Pull Request Guidelines

Commit subjects follow Conventional Commits: `type(scope): imperative subject`, lower-case and without a trailing period, for example `fix(theme): stop switch-theme.sh hanging on the borders daemon`. The types in use are `feat`, `fix`, `refactor`, `chore` and `docs`; the scope is the tool or directory touched (`zsh`, `claude`, `skills`, `dev`, `context`, `install`, `brew`, `git`). Keep commits focused. PRs should explain the user-facing effect, list any manual setup or migration steps, and include terminal output or screenshots when changing interactive tooling, themes, or editor behavior.

## Security & Configuration Tips

Do not commit secrets or machine-specific auth state. Keep sensitive values in local files like `zsh/.zsh_secrets`, and prefer updating tracked templates, scripts, or docs instead of hardcoding personal paths unless the repo already standardizes them.
