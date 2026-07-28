# Tools & Shortcuts Guide

Quick-reference for the terminal workflow tools, keybindings, and shell helpers.

## New CLI Tools

| Tool | Replaces | What it does | Usage |
|------|----------|-------------|-------|
| `bat` | `cat` | Syntax-highlighted file viewer | `bat file.ts`, `bat --diff file.ts` |
| `eza` | `ls` | Modern file listing with icons | `ll` (long, all), `lt` (tree) |
| `fd` | `find` | Fast file finder | `fd pattern`, `fd -e ts`, `fd -t d` (dirs) |
| `fzf` | — | Fuzzy finder for anything | `ff` (files+preview), `eff` (open in editor) |
| `ripgrep` | `grep` | Fast content search | `rg pattern`, `rg -t ts pattern`, `rg -l pattern` (files only) |
| `zoxide` | `cd` | Smart directory jumper | `z project-name`, `zi` (interactive) |
| `lazygit` | — | TUI git client | `lazygit` or `Space g g` in Neovim |
| `lazydocker` | — | TUI Docker manager | `lazydocker` |
| `starship` | PS1 | Shell prompt with git/language info | Auto-active, no commands needed |
| `mise` | nvm/rbenv | Runtime version manager | `mise use node@22`, `mise ls`, `mise install` |
| `btop` | top/htop | System monitor | `btop` |

Node is still managed by nvm, not mise: `.zshrc` activates the default version at startup and switches automatically when you `cd` into a directory with an `.nvmrc`.

## Shell Aliases & Functions

| Name | What it does |
|------|--------------|
| `t` | `tmux new-session -A -s main` (attach or create) |
| `codex` | `codex --yolo` |
| `ll` | `eza -lha --group-directories-first --icons=auto` (includes hidden) |
| `lt` | `eza --icons=auto --tree --level=2` |
| `ff` | `fzf` with bat preview |
| `eff` | Open the fzf pick in `$EDITOR` |
| `notify <cmd>` | Run a command, then fire a desktop notification with its exit status |
| `no-sleep yes\|no` | Keep the Mac awake (even lid-closed on battery), or restore pmset defaults |
| `docker ps` | Overridden to `docker ps -a` in a name + status table; any other arguments pass straight through to docker |

### Git

| Alias | Expands to |
|-------|-----------|
| `gs` | `git status -sb` |
| `ga` / `gaa` | `git add` / `git add --all` |
| `gapa` | `git add --patch` |
| `gap` | `git add -N . && git add -p` (includes untracked files) |
| `gcm` / `gcam` | `git commit -m` / `git commit -a -m` |
| `gca` / `gcan` / `gcad` | `git commit --amend` / `--amend --no-edit` / `-a --amend` |
| `gco` / `gcb` | `git checkout` / `git checkout -b` |
| `gb` / `gbd` | `git branch --no-column` / `git branch -D` |
| `gl` / `gp` | `git pull` / `git push` |
| `gpf` | `git push --force-with-lease` |
| `gpn` / `gpfn` | The two pushes with `--no-verify` |
| `grb` / `gm` | `git rebase` / `git merge` |
| `grh` / `grhs` / `grhh` | `git reset` / `--soft` / `--hard` |
| `gsh` | `git show` |
| `glo [n]` | `git log --oneline --no-decorate`, optionally limited to `n` commits |
| `glc` | Copy `HEAD`'s SHA to the clipboard |
| `gwl` | `git worktree list` |

Branch-name completion is wired up for `gco`, `gcb`, `grb`, `gm`, `gbd`, `grh`, `grhh`, `grhs` and `gsh`.

## Tmux

Prefix key: `Ctrl+Space` (secondary: `Ctrl+B`)

Two rebinds bite if you expect tmux defaults: `prefix + z` kills the pane (it is not zoom) and `prefix + Z` kills the whole window, both without a confirmation prompt.

### Panes

| Action | Binding |
|--------|---------|
| Split right | `prefix + %` |
| Split below | `prefix + "` |
| Navigate (seamless) | `Ctrl+h/j/k/l` (no prefix; works across nvim splits and tmux panes, stops at the edge) |
| Swap pane in a direction | `Ctrl+Shift+h/j/k/l` (no prefix; focus follows the pane) |
| Resize | `prefix + h/j/k/l` (repeatable) |
| Equalize sizes (keeps the layout) | `prefix + =` |
| Flip split orientation | `prefix + s` |
| Select pane N | `Right Option + 1` through `Right Option + 5` (no prefix) |
| Break pane into its own window | `prefix + b` |
| Kill pane | `prefix + z` or `prefix + <` (no confirm), `prefix + x` (confirms) |
| Zoom/unzoom pane | No key binding — right-click the pane and pick Zoom; the status bar shows `ZOOM` |

### Windows

| Action | Binding |
|--------|---------|
| New window | `prefix + c` |
| Kill window | `prefix + Z` (no confirm) or `prefix + &` (confirms) |
| Rename window | `prefix + r` |
| Jump to window N | `prefix + 1` through `prefix + 6` |
| Previous/next window | `prefix + Left/Right` (also `prefix + p/n`) |
| Move window left/right in the order | `prefix + H/L` (repeatable) |
| Merge other windows in as splits | `prefix + m`, then the window numbers |

### Sessions

| Action | Binding |
|--------|---------|
| New session | `prefix + C` |
| Kill session | `prefix + Q` |
| Rename session | `prefix + R` |
| Previous/next session | `prefix + P/N` or `prefix + Up/Down` |
| Detach | `prefix + d` |

### Copy Mode

| Action | Binding |
|--------|---------|
| Enter copy mode | `prefix + w` (or `prefix + [`) |
| Start selection | `v` |
| Yank (copy) | `y` |

### Other

| Action | Binding |
|--------|---------|
| Reload config | `prefix + q` |
| List every binding | `prefix + ?` |
| Clear screen | `Ctrl+ø` (no prefix; Alacritty sends a private sequence that tmux turns into `Ctrl+l`) |
| Send a literal `Esc` to a Codex pane | `F12` (bare `Esc` is swallowed there, so `Ctrl+C` is the interrupt) |

## Neovim (LazyVim)

Leader key: `Space`

Press `Space` and wait for the which-key popup to see all available commands.

### Files & Navigation

| Action | Binding |
|--------|---------|
| Fuzzy find file | `Space Space` |
| Grep search all files | `Space s g` |
| Toggle file tree | `Space e` |
| Jump between sidebar and editor | `Ctrl+w w` |
| Resize sidebar | `Ctrl+Left/Right` |

### Buffers

| Action | Binding |
|--------|---------|
| Previous buffer | `Shift+H` |
| Next buffer | `Shift+L` |
| Close buffer | `Space b d` |
| Close other buffers | `Space b o` |

### Git

| Action | Binding |
|--------|---------|
| Open lazygit | `Space g g` |

### Custom Keymaps

| Action | Binding |
|--------|---------|
| Copy relative path of current file | `Space y p` |
| Copy absolute path of current file | `Space y P` |
| Move line/selection up | `ø e` |
| Move line/selection down | `æ e` |

Line moving replaces LazyVim's `Alt+j/k`, which AeroSpace swallows.

### File Tree (snacks explorer)

| Action | Key |
|--------|-----|
| Add file (or directory, with a trailing `/`) | `a` |
| Delete | `d` |
| Move | `m` |
| Copy | `c` |
| Rename | `r` |
| Yank path | `y` |
| Toggle hidden / ignored files | `H` / `I` |
| Show help | `?` |

Hidden and gitignored files are shown by default in both the explorer and the file picker.

## Tmux Layout Functions

Run these inside an existing tmux session.

### `tdl` — Dev Layout

Creates editor + AI + terminal panes:

```
┌──────────┬─────────┐
│          │   AI    │
│  Editor  │  Agent  │
│  (70%)   │  (30%)  │
├──────────┼─────────┤
│    Terminal (15%)   │
└─────────────────────┘
```

```sh
tdl cc                  # editor + claude code + terminal
tdl cx                  # editor + codex + terminal
tdl cc cx               # editor + claude code + codex + terminal
```

### `tdlm` — Dev Layout Multiplier

Creates a `tdl` layout for each subdirectory in the current directory, one window per subdirectory. Useful for monorepos.

```sh
tdlm claude
```

### `tsl` — Swarm Layout

Creates N tiled panes all running the same command.

```sh
tsl 4 claude            # 4 panes of claude
tsl 3 "claude --model sonnet"  # multi-word commands work
```

Unlike `tdl`, `tsl` does not expand the `cc`/`cx` shorthands — pass the real command.
