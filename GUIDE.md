# Tools & Shortcuts Guide

Quick-reference for the terminal workflow tools, keybindings, and shell helpers.

## New CLI Tools

| Tool | Replaces | What it does | Usage |
|------|----------|-------------|-------|
| `bat` | `cat` | Syntax-highlighted file viewer | `bat file.ts`, `bat --diff file.ts` |
| `eza` | `ls` | Modern file listing with icons | `ls` (aliased), `lsa` (all), `lt` (tree) |
| `fd` | `find` | Fast file finder | `fd pattern`, `fd -e ts`, `fd -t d` (dirs) |
| `fzf` | — | Fuzzy finder for anything | `ff` (files+preview), `eff` (open in editor), `Ctrl+R` (history) |
| `ripgrep` | `grep` | Fast content search | `rg pattern`, `rg -t ts pattern`, `rg -l pattern` (files only) |
| `zoxide` | `cd` | Smart directory jumper | `z project-name`, `zi` (interactive) |
| `lazygit` | — | TUI git client | `lazygit` or `Space g g` in Neovim |
| `lazydocker` | — | TUI Docker manager | `lazydocker` |
| `starship` | PS1 | Shell prompt with git/language info | Auto-active, no commands needed |
| `mise` | nvm/rbenv | Runtime version manager | `mise use node@22`, `mise ls`, `mise install` |
| `btop` | top/htop | System monitor | `btop` |

## Shell Aliases

| Alias | Expands to |
|-------|-----------|
| `n` | `nvim` |
| `g` | `git` |
| `d` | `docker` |
| `t` | `tmux new-session -A -s Work` (attach or create) |
| `cc` | `claude` |
| `cx` | `codex` |
| `oc` | `opencode` |
| `ff` | `fzf` with bat preview |
| `eff` | Open fzf result in `$EDITOR` |
| `ls` | `eza -lh --group-directories-first --icons=auto` |
| `lsa` | `eza -lha ...` (includes hidden) |
| `lt` | `eza --tree --level=2` |

## Tmux

Prefix key: `Ctrl+Space` (secondary: `Ctrl+B`)

### Panes

| Action | Binding |
|--------|---------|
| Split right | `prefix + v` |
| Split below | `prefix + s` |
| Navigate (vim) | `prefix + h/j/k/l` |
| Navigate (arrows) | `Ctrl+Alt+Arrows` (no prefix) |
| Navigate (seamless) | `Ctrl+h/j/k/l` (works across nvim splits and tmux panes) |
| Resize (vim) | `prefix + H/J/K/L` |
| Resize (arrows) | `Ctrl+Alt+Shift+Arrows` (no prefix) |
| Select pane N | `prefix + 1` through `prefix + 6` |
| Kill pane | `prefix + z` |
| Zoom/unzoom pane | `prefix + Z` (tmux default) |

### Windows

| Action | Binding |
|--------|---------|
| New window | `prefix + c` |
| Kill window | `prefix + x` (then confirm) |
| Rename window | `prefix + r` |
| Jump to window N | `prefix + Shift+1` through `prefix + Shift+6` |
| Previous/next window | `prefix + Left/Right` |

### Sessions

| Action | Binding |
|--------|---------|
| New session | `prefix + C` |
| Kill session | `prefix + Q` |
| Rename session | `prefix + R` |
| Previous/next session | `prefix + P/N` or `prefix + Up/Down` |
| List sessions | `prefix + s` |
| Detach | `prefix + d` |

### Copy Mode

| Action | Binding |
|--------|---------|
| Enter copy mode | `prefix + [` |
| Start selection | `v` |
| Yank (copy) | `y` |

### Other

| Action | Binding |
|--------|---------|
| Reload config | `prefix + q` |
| Clear screen | `prefix + Ctrl+l` |

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

### File Tree (neo-tree)

| Action | Key |
|--------|-----|
| Add new file | `a` |
| Add new directory | `Shift+A` |
| Delete | `d` |
| Move | `m` |
| Rename | `r` |
| Show help | `?` |

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
