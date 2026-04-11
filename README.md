# Mac Setup

This repo is the source of truth for Philip's local Mac development environment.

An agent setting up a new Mac should use this file as the bootstrap checklist.

## Scope

This repo currently manages:

- Homebrew packages and VS Code/Cursor extensions via [Brewfile](/Users/philip/.config/Brewfile)
- Shell config in [zsh/.zshrc](/Users/philip/.config/zsh/.zshrc) — git aliases, dev tool wrappers, Omarchy-style aliases (`n`, `g`, `d`, `t`), tmux layout functions (`tdl`, `tdlm`, `tsl`), and tool inits (eza, zoxide, fzf, starship, mise)
- Terminal config in [alacritty/alacritty.toml](/Users/philip/.config/alacritty/alacritty.toml) — JetBrainsMono Nerd Font, light/dark themes, Option-as-Alt for tmux
- Tmux config in [tmux/tmux.conf](/Users/philip/.config/tmux/tmux.conf) — Omarchy-style bindings (Ctrl+Space prefix, vim pane nav, Alt window/session nav, vi copy mode, vim-tmux-navigator, blue status bar)
- Neovim config in [nvim/](/Users/philip/.config/nvim/) — LazyVim with Tokyo Night theme and vim-tmux-navigator
- Cursor config in [cursor/settings.json](/Users/philip/.config/cursor/settings.json) and [cursor/keybindings.json](/Users/philip/.config/cursor/keybindings.json)
- Claude/Codex config under `claude/`, `codex/`, and `.claude/`
- Utility scripts under [dev](/Users/philip/.config/dev)
- Bootstrap script in [install.sh](/Users/philip/.config/install.sh)

This repo does not fully manage:

- SSH keys
- GitHub authentication state
- 1Password/logins
- macOS system settings
- Docker Desktop installation
- Bun install state
- private secrets in `~/.config/zsh/.zsh_secrets`

## Before Wiping The Mac

Before erasing the machine, make sure the following are backed up or intentionally recoverable.

Critical:

- SSH keys in `~/.ssh`
- shell secrets in `~/.config/zsh/.zsh_secrets`
- any other local `.env` files or credentials not stored in this repo

Important:

- export or sync browser bookmarks, saved passwords, and profiles if they matter
- verify cloud credentials can be restored, including AWS config under `~/.aws` if needed
- confirm NVM-installed Node versions you rely on are documented somewhere
- confirm any manually installed global npm tools you care about are documented somewhere
- verify Karabiner/Aerospace or other app settings are either already in this repo or backed up elsewhere
- verify local databases, scratch files, Downloads, Desktop files, and note folders do not contain anything you still need

Useful final checks:

- run `gh auth status`
- inspect `~/.ssh`
- inspect `~/.config/zsh/.zsh_secrets`
- inspect `~/.aws`
- inspect `~/.cursor`, `~/.claude`, and `~/Library/Application Support` for app state you may want to preserve
- inspect `~/Documents`, `~/Desktop`, and `~/Downloads` for anything not synced elsewhere
- inspect `brew leaves` if you want to capture any additional intentionally installed tools into [Brewfile](/Users/philip/.config/Brewfile)

## Assumptions

- Machine is a fresh macOS install
- Repo will live at `~/.config`
- User account is `philip`
- Homebrew is installed to `/opt/homebrew`

If any of those change, adjust paths before linking files.

## Expected Folder Structure

This setup assumes a small number of stable top-level directories under `~`.

```text
~
├── .config
├── work
│   ├── <main repos>
│   ├── worktrees
│   └── .dev-stacks
├── private
├── vaults
└── bin
```

Notes:

- `~/.config` contains this repo and the managed local configuration
- `~/work` contains main working repositories such as `ledidi-monorepo`, `legacy`, and related work repos
- `~/work/worktrees` is used for git worktrees and is referenced by shell helpers like `gwd`
- `~/work/.dev-stacks` is used by the local `dev` tooling for generated Docker Compose stack files
- `~/private` contains private/personal repositories
- `~/vaults` contains Obsidian or other note vaults
- `~/bin` contains symlinks to helper scripts from this repo

## Bootstrap Order

1. Install Xcode Command Line Tools:

```sh
xcode-select --install
```

2. Install Homebrew:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

3. Clone this repo to the expected location:

```sh
git clone <repo-url> ~/.config
```

4. Run the install script:

```sh
~/.config/install.sh
```

This handles everything: Homebrew packages, directory creation, symlinks, stale symlink cleanup, neovim cache prep, and zsh-autosuggestions. See [install.sh](/Users/philip/.config/install.sh) for details.

Note: tmux reads its config directly from `~/.config/tmux/tmux.conf` (XDG support since tmux 3.1). No `~/.tmux.conf` symlink is needed.

## Manual Follow-Up

These steps are intentionally not automated by this repo and should be handled manually:

- Create `~/.config/zsh/.zsh_secrets`
- Restore `~/.ssh`
- Sign in to GitHub CLI with `gh auth login`
- Install and sign in to Docker Desktop
- Reinstall or restore Cursor and sign in
- Reinstall or restore Claude Desktop / related apps if needed
- Create a sync code for Brave before wiping (Settings > Sync > Start a new Sync Chain)
- Install the required Node version and set it as the default:

```sh
nvm install 24
nvm alias default 24
```
- Restore Bun if still needed
- Increase key repeat speed for comfortable Vim navigation (System Settings > Keyboard):
  - Set **Key repeat rate** to **Fast**
  - Set **Delay until repeat** to **Short**
- Launch `nvim` once to bootstrap LazyVim plugins (takes ~30-60 seconds, requires internet)
- Start background services:

```sh
brew services start felixkratz/formulae/borders
open -a AeroSpace
open -a Karabiner-Elements
open -a Raycast
```

## Notes About Current Shell Config

[zsh/.zshrc](/Users/philip/.config/zsh/.zshrc) expects these tools or paths to exist:

- Homebrew in `/opt/homebrew`
- `~/bin`
- Docker Desktop CLI path
- `~/.nvm`
- `~/.pyenv`
- `~/.bun`
- `~/.config/zsh/.zsh_secrets`

If any of these are missing, the shell will still mostly work, but some PATH entries or commands may be ineffective until restored.

## Verification

Run these checks after setup:

```sh
brew bundle check --file ~/.config/Brewfile
zsh -lc 'command -v nvm uv brew tmux nvim watchman lefthook gh'
zsh -lc 'command -v lazygit fzf bat eza zoxide starship rg fd'
zsh -lc 'command -v dev check tests tunnel gwc gwd sync-context fix'
cursor --list-extensions
tmux -V
nvim --version | head -n 1
nvm --version
uv --version
```

## Repo-Specific Tooling Installed Via Brewfile

The Brewfile is intended to cover the stable baseline:

- CLI/runtime tools like `gh`, `tmux`, `neovim`, `nvm`, `uv`, `watchman`, `lefthook`
- Modern CLI replacements: `bat`, `eza`, `fd`, `fzf`, `ripgrep`, `zoxide`, `starship`
- Development TUIs: `lazygit`, `lazydocker`, `btop`
- Runtime management: `mise`, `node`
- Window manager and app casks like `aerospace`, `alacritty`, and `chai`
- Cursor/VS Code extensions needed for the current repo mix

If a new machine is missing something that should always be present, add it to [Brewfile](/Users/philip/.config/Brewfile) rather than documenting it only here.

## Agent Rules

When using this repo to provision a new Mac:

- Prefer updating [Brewfile](/Users/philip/.config/Brewfile) over ad hoc installs
- Prefer symlinks into `~/.config` rather than copying files
- Do not overwrite secrets, SSH keys, or auth state
- Keep the repo path at `~/.config` unless there is a strong reason not to
- If a tool is required by [zsh/.zshrc](/Users/philip/.config/zsh/.zshrc), either install it or clearly document the missing dependency
