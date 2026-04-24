# ── Aliases ─────────────────────────────────────────

# Git
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gb='git branch --no-column'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gcam='git commit -a -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gbd='git branch -D'
alias gl='git pull'
glo() { git log --oneline --no-decorate ${1:+-n $1}; }
alias gp='git push'
alias gpn='git push --no-verify'
alias gpf='git push --force-with-lease'
alias gpfn='git push --force-with-lease --no-verify'
alias grb='git rebase'
alias gm='git merge'
alias grh='git reset'
alias grhh='git reset --hard'
alias grhs='git reset --soft'
alias gsh='git show'
alias gs='git status -sb'
alias gcm='git commit -m'
alias glc='git rev-parse HEAD | tr -d "\n" | pbcopy && echo "Copied: $(git rev-parse HEAD)"'
alias gwl='git worktree list'


# ── Environment ─────────────────────────────────────

# Homebrew (must be early — tools come from here)
export PATH="/usr/local/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"

# System and tool PATHs
export PATH="$HOME/bin:$PATH"
export PATH="$PATH:$HOME/go/bin"
export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"
export PATH="$PATH:/Users/philip/.modular/bin"
export PATH="/Users/philip/.duckdb/cli/latest:$PATH"
export PATH="/opt/homebrew/opt/gradle@8/bin:$PATH"
export PATH=/Users/philip/.opencode/bin:$PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="/Users/philip/.browser-use/bin:$PATH"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# NVM (must load before npm config get prefix)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
(( $+commands[npm] )) && export PATH="$PATH:$(npm config get prefix)/bin"

# OpenJDK
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk@17/include"

# Disable telemetry and warnings
export DISABLE_TELEMETRY=1
export DISABLE_ERROR_REPORTING=1
export NODE_NO_WARNINGS=1
export POSTGRES_URL=postgres://postgres:postgres@localhost:5432/registries

# Telegram (PhilTheBoyBot) — used by Claude Code Stop hook



# Secrets
[ -f "$HOME/.config/zsh/.zsh_secrets" ] && source "$HOME/.config/zsh/.zsh_secrets"


# ── Shell options & history ─────────────────────────

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
unsetopt SHARE_HISTORY
unsetopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE

export PS1='%c %# '  # Fallback (overridden by starship if installed)

fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
autoload -Uz compinit && compinit

# ── Functions ───────────────────────────────────────

# Git & worktrees

gwc() {
  /Users/philip/.config/dev/gwc.sh "$@"
}

_gwc_completions() {
  local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
  _describe 'branch' branches
}
compdef _gwc_completions gwc

gwd() {
  /Users/philip/.config/dev/gwd.sh "$@"
}

_gwd_completions() {
  local dir="/Users/philip/work/worktrees"
  local worktrees=(${(@f)"$(ls "$dir" 2>/dev/null)"})
  _describe 'worktree' worktrees
}
compdef _gwd_completions gwd

sync-context() {
  /Users/philip/.config/dev/sync-context.sh "$@"
}

# Git alias completions
_git_local_branches() {
  local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
  _describe 'branch' branches
}

compdef _git_local_branches gco gcb grb gm gbd grh grhh grhs gsh
compdef _git gp=git-push
compdef _git gpf=git-push
compdef _git gl=git-pull
compdef _git ga=git-add
compdef _git gapa=git-add
compdef _git gb=git-branch
compdef _git glo=git-log

# Dev tools

dev() {
  /Users/philip/.config/dev/dev.sh "$@"
}

_dev_completions() {
  local commands=("up" "down" "stop" "start" "restart" "nuke" "status" "exec" "logs" "ps" "build")
  _describe 'command' commands
}
compdef _dev_completions dev

check() {
  /Users/philip/.config/dev/check.sh "$@"
}

_check_completions() {
  local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
  _describe 'branch' branches
}
compdef _check_completions check

_tests_completions() {
  local suites=("frontend:Frontend unit tests (Vitest)" "registries:Registries service tests (Jest)" "e2e:Frontend E2E tests (Playwright)")
  _describe 'suite' suites
}
compdef _tests_completions tests

fix() {
  /Users/philip/.config/dev/fix.sh "$@"
}

_fix_completions() {
  local cmds=("build:Rebuild Docker images" "full:npm install + rebuild")
  _describe 'command' cmds
}
compdef _fix_completions fix

prisma() {
  local monorepo_root
  monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not inside a git repository"
    return 1
  }
  local project_name slot worktree_slot_file
  project_name="$(basename "$monorepo_root")"
  worktree_slot_file="${DEV_STACKS_DIR:-$HOME/work/.dev-stacks}/$project_name/worktree-slot"
  if [[ -f "$worktree_slot_file" ]]; then
    slot=$(cat "$worktree_slot_file")
  else
    slot=0
  fi
  local port=$((5432 + slot * 100))
  (cd "$monorepo_root/services/registries" &&
    POSTGRES_URL="postgresql://postgres:postgres@localhost:$port/registries" \
      npx prisma studio "$@")
}

# Utilities

notify() {
  eval "$@"
  local exit_code=$?
  if [ $exit_code -eq 0 ]; then
    alerter -message "Command succeeded" -title "Done" -sound "Hero" -timeout 5 > /dev/null 2>&1 &
  else
    alerter -message "Command failed (exit $exit_code)" -title "Done" -sound "Sosumi" -timeout 5 > /dev/null 2>&1 &
  fi
  return $exit_code
}

docker() {
  if [[ $@ == "ps" ]]; then
    command docker ps -a --format "table {{.Names}}\t{{.Status}}"
  else
    command docker "$@"
  fi
}


# ── Terminal workflow ──────────────────────────────

# Quick aliases
alias gcad='git commit -a --amend'
alias gap='git add -N . && git add -p'
alias t='tmux new-session -A -s main'
alias claude='claude --dangerously-skip-permissions'
alias codex='codex --yolo'

# Modern ls (eza)
if command -v eza &> /dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias ll='eza -lh --group-directories-first --icons=auto'
  alias lsa='eza -lha --group-directories-first --icons=auto'
  alias lt='eza --icons=auto --tree --level=2'
fi

# Fuzzy finder with preview
alias ff='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}"'

# Open fuzzy-find result in editor
eff() {
  local file
  file=$(fzf --preview "bat --color=always --style=numbers --line-range=:500 {}")
  [ -n "$file" ] && ${EDITOR:-nvim} "$file"
}

# Zoxide (smart cd)
if command -v zoxide &> /dev/null; then
  eval "$(zoxide init zsh)"
fi

# Mise runtime manager
if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

# Starship prompt
export STARSHIP_CONFIG="$HOME/.config/starship.toml"
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

# ── Tmux layout functions ─────────────────────────

# tdl: Tmux Dev Layout — 3/4-pane IDE layout (run inside tmux)
#   ┌──────────┬─────────┐
#   │          │   AI    │
#   │  Editor  │  Agent  │
#   │          ├─────────┤
#   ├──────────┤ (2nd AI)│
#   │ Terminal │         │
#   └──────────┴─────────┘
_tdl_yolo() {
  case "$1" in
    cc|claude) echo "claude" ;;
    cx|codex)  echo "codex" ;;
    *)         echo "$1" ;;
  esac
}

_tdl_ai_kind() {
  case "$1" in
    cc|claude|claude\ *) echo "claude" ;;
    cx|codex|codex\ *)   echo "codex" ;;
    *)                   echo "other" ;;
  esac
}

tdl() {
  if [ -z "$1" ]; then
    echo "Usage: tdl <ai_command> [<second_ai_command>]"
    echo "  e.g.: tdl cc         (editor + claude code + terminal)"
    echo "  e.g.: tdl cx         (editor + codex + terminal)"
    echo "  e.g.: tdl cc cx      (editor + claude code + codex + terminal)"
    return 1
  fi

  local ai_cmd="$(_tdl_yolo "$1")"
  local second_ai_cmd="${2:+$(_tdl_yolo "$2")}"
  local ai_kind="$(_tdl_ai_kind "$1")"
  local second_ai_kind="${2:+$(_tdl_ai_kind "$2")}"
  local editor_pane="$TMUX_PANE"

  tmux rename-window "$(basename "$PWD")"

  # Split: 15% bottom for terminal
  local terminal_pane=$(tmux split-window -v -l 15% -c "#{pane_current_path}" -P -F '#{pane_id}')
  tmux select-pane -t "$terminal_pane" -T "shell"

  # Split editor pane: 30% right for AI
  local ai_pane=$(tmux split-window -h -t "$editor_pane" -l 30% -c "#{pane_current_path}" -P -F '#{pane_id}')
  tmux select-pane -t "$ai_pane" -T "ai:$ai_kind"

  # Optional: split AI pane for second AI
  if [ -n "$second_ai_cmd" ]; then
    local second_ai_pane=$(tmux split-window -v -t "$ai_pane" -l 50% -c "#{pane_current_path}" -P -F '#{pane_id}')
    tmux select-pane -t "$second_ai_pane" -T "ai:$second_ai_kind"
    tmux send-keys -t "$second_ai_pane" "clear && $second_ai_cmd" Enter
  fi

  tmux send-keys -t "$ai_pane" "clear && $ai_cmd" Enter
  tmux send-keys -t "$editor_pane" "${EDITOR:-nvim} ." Enter
  tmux select-pane -t "$editor_pane"
}

# tdlm: Tmux Dev Layout Multiplier — tdl per subdirectory
tdlm() {
  if [ -z "$1" ]; then
    echo "Usage: tdlm <ai_command> [<second_ai_command>]"
    return 1
  fi

  local ai_cmd="$1"
  local second_ai_cmd="$2"
  local first_window=true

  for dir in */; do
    [ -d "$dir" ] || continue
    dir="${dir%/}"

    if [ "$first_window" = true ]; then
      tmux rename-window "$dir"
      pushd "$dir" > /dev/null
      tdl "$ai_cmd" "$second_ai_cmd"
      popd > /dev/null
      first_window=false
    else
      tmux new-window -n "$dir" -c "$(pwd)/$dir"
      pushd "$dir" > /dev/null
      tdl "$ai_cmd" "$second_ai_cmd"
      popd > /dev/null
    fi
  done
}

# tsl: Tmux Swarm Layout — N tiled panes running the same command
tsl() {
  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: tsl <pane_count> <command>"
    echo "  e.g.: tsl 4 cx      (4 panes of Claude Code)"
    return 1
  fi

  local count="$1"
  shift
  local cmd="$*"
  local ai_kind="$(_tdl_ai_kind "$cmd")"

  tmux rename-window "swarm"
  tmux select-pane -T "ai:$ai_kind"
  tmux send-keys "clear && $cmd" Enter

  for ((i = 2; i <= count; i++)); do
    local pane_id=$(tmux split-window -c "#{pane_current_path}" -P -F '#{pane_id}')
    tmux select-pane -t "$pane_id" -T "ai:$ai_kind"
    tmux send-keys "clear && $cmd" Enter
    tmux select-layout tiled
  done

  tmux select-layout tiled
}


# ── Plugins & keybindings ───────────────────────────

source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# Shift+Tab to accept autosuggestion
bindkey -r '\e[Z' 2>/dev/null
bindkey -r '^[[Z' 2>/dev/null
bindkey '\e[Z' autosuggest-accept
bindkey '^[[Z' autosuggest-accept
bindkey -M viins '\e[Z' autosuggest-accept
bindkey -M viins '^[[Z' autosuggest-accept
bindkey -M emacs '\e[Z' autosuggest-accept
bindkey -M emacs '^[[Z' autosuggest-accept

# bun completions
[ -s "/Users/philip/.bun/_bun" ] && source "/Users/philip/.bun/_bun"
