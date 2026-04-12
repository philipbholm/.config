# Repository Guidelines

## Project Structure & Module Organization

This repository is a macOS dotfiles and workflow repo rooted at `~/.config`. Top-level directories map directly to managed tools: `zsh/`, `tmux/`, `nvim/`, `alacritty/`, `git/`, `cursor/`, `claude/`, and `codex/`. Development automation lives in `dev/`, including worktree helpers (`gwc.sh`, `gwd.sh`), Docker stack tooling (`dev.sh`), and verification scripts (`check.sh`, `tests.sh`). `dev/admin-mock/` is the only standalone TypeScript package in the repo.

## Build, Test, and Development Commands

Use the repo from `~/.config`.

- `./install.sh` installs brew dependencies, creates expected directories, and refreshes symlinks.
- `zsh -lc 'source zsh/.zshrc'` smoke-tests shell config syntax and startup.
- `bash dev/gwc.sh <branch>` creates a worktree and bootstraps the target monorepo environment.
- `bash dev/dev.sh status` shows active dev stacks; `bash dev/dev.sh up` starts the current stack when run inside a supported repo.
- `zsh dev/check.sh --all registries` runs lint/build checks for a target service in the Ledidi monorepo.
- `zsh dev/tests.sh --all frontend` runs the corresponding test suite in that monorepo.
- `cd dev/admin-mock && npm run build` verifies the local TypeScript helper app builds.

## Coding Style & Naming Conventions

Shell scripts use `bash` or `zsh` with `set -euo pipefail`. Keep functions small, prefer explicit variable names, and preserve existing 2- or 4-space indentation per file. Name scripts in kebab-case, for example `setup-stack.sh`. Lua config belongs under `nvim/lua/...`; TypeScript in `dev/admin-mock/src/`.

## Testing Guidelines

There is no single repo-wide test runner. Validate changes with the narrowest relevant command: shell configs via `zsh -lc`, bootstrap changes via `./install.sh` on a safe machine, dev workflow changes via `dev/check.sh` or `dev/tests.sh`, and `dev/admin-mock` changes via `npm run build`. Add small smoke-test steps to documentation when behavior is manual.

## Commit & Pull Request Guidelines

Recent history uses short imperative subjects such as `Fix errors` and `Add more git aliases`. Keep commits focused and descriptive. PRs should explain the user-facing effect, list any manual setup or migration steps, and include terminal output or screenshots when changing interactive tooling, themes, or editor behavior.

## Security & Configuration Tips

Do not commit secrets or machine-specific auth state. Keep sensitive values in local files like `zsh/.zsh_secrets`, and prefer updating tracked templates, scripts, or docs instead of hardcoding personal paths unless the repo already standardizes them.
