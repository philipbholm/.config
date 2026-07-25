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
export PATH="$HOME/.config/claude/bin:$PATH"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# NVM (must load before npm config get prefix)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
command -v nvm >/dev/null && nvm use default --silent >/dev/null

# Auto-switch Node version on cd when a directory (or ancestor) has an .nvmrc
if command -v nvm >/dev/null; then
  autoload -U add-zsh-hook
  load-nvmrc() {
    local nvmrc_path nvmrc_node_version
    nvmrc_path="$(nvm_find_nvmrc)"
    if [ -n "$nvmrc_path" ]; then
      nvmrc_node_version="$(nvm version "$(cat "$nvmrc_path")")"
      if [ "$nvmrc_node_version" = "N/A" ]; then
        echo "nvm: installing Node version pinned in $nvmrc_path"
        nvm install
      elif [ "$nvmrc_node_version" != "$(nvm version)" ]; then
        nvm use --silent
      fi
    elif [ -n "$(PWD=$OLDPWD nvm_find_nvmrc)" ] && [ "$(nvm version)" != "$(nvm version default)" ]; then
      nvm use default --silent
    fi
  }
  add-zsh-hook chpwd load-nvmrc
  load-nvmrc
fi

(( $+commands[npm] )) && export PATH="$PATH:$(npm config get prefix)/bin"

# OpenJDK
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk@17/include"

# Disable telemetry and warnings
export NODE_NO_WARNINGS=1
export POSTGRES_URL=postgres://postgres:postgres@localhost:5432/registries

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

# no-sleep yes -> prevent Mac from sleeping (even lid-closed, on battery)
# no-sleep no  -> restore normal pmset settings
no-sleep() {
  case "$1" in
    yes)
      sudo pmset -a disablesleep 1 sleep 0 || return $?
      echo "Sleep disabled"
      ;;
    no)
      sudo pmset -a disablesleep 0 || return $?
      sudo pmset -b sleep 1 displaysleep 2
      sudo pmset -c sleep 0 displaysleep 10
      echo "Sleep restored"
      ;;
    *)
      echo "Usage: no-sleep yes|no" >&2
      return 1
      ;;
  esac
}


# ── Terminal workflow ──────────────────────────────

# Quick aliases
alias gcad='git commit -a --amend'
alias gap='git add -N . && git add -p'
alias t='tmux new-session -A -s main'
alias codex='codex --yolo'

# Modern ls (eza)
if command -v eza &> /dev/null; then
  alias ll='eza -lha --group-directories-first --icons=auto'
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

# ── Work profile (only present/sourced on work machines) ────
[ -d "$HOME/work" ] && [ -f "$HOME/.config/zsh/.zshrc.work" ] && \
  source "$HOME/.config/zsh/.zshrc.work"
