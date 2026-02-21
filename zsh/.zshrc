# ── Aliases ─────────────────────────────────────────

# General
alias ls='ls --color'
alias ll='ls -lah --color'

# Git
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gb='git branch --no-column'
alias gcan='git commit --amend --no-edit'
alias gcam='git commit -a -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gbd='git branch -D'
alias gl='git pull'
glo() { git log --oneline --no-decorate ${1:+-n $1}; }
alias gp='git push'
alias gpf='git push --force-with-lease'
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

# NVM (must load before npm config get prefix)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
export PATH="$PATH:$(npm config get prefix)/bin"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# OpenJDK
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk@17/include"

# Disable telemetry and warnings
export DISABLE_TELEMETRY=1
export DISABLE_ERROR_REPORTING=1
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

export PS1='%c %# '  # Current directory


# ── Functions ───────────────────────────────────────

# Git & worktrees

gwc() {
  [[ -z "$1" ]] && { echo "Usage: gwc <branch-name>"; return 1; }
  setopt LOCAL_OPTIONS NO_MONITOR
  local worktree_path="/Users/philip/work/worktrees/$1"
  local claude_src="/Users/philip/.config/dev/claude/ledidi-monorepo"
  git worktree add "$worktree_path" "$1" 2>/dev/null || return 1
  # Copy CLAUDE.local.md files from config to worktree
  (cd "$claude_src" && find . -name 'CLAUDE.local.md' -exec sh -c '
    for file; do
      mkdir -p "'"$worktree_path"'/$(dirname "$file")"
      cp "$file" "'"$worktree_path"'/$file"
    done
  ' _ {} +)
  # Run setup-worktree.sh in the new worktree (suppressed output with spinner)
  cp /Users/philip/.config/dev/setup-worktree.sh "$worktree_path/"
  local log_file=$(mktemp)
  (
    (cd "$worktree_path" && bash setup-worktree.sh > "$log_file" 2>&1) &
    local pid=$!
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    while kill -0 $pid 2>/dev/null; do
      printf "\r  ${spin:$i:1} Setting up worktree..."
      i=$(( (i + 1) % ${#spin} ))
      sleep 0.1
    done
    wait $pid
    exit $?
  )
  local exit_code=$?
  printf "\r\033[K"
  if [ $exit_code -ne 0 ]; then
    echo "Worktree setup failed. Log: $log_file"
    rm -f "$worktree_path/setup-worktree.sh"
    return 1
  fi
  rm -f "$log_file"
  rm -f "$worktree_path/setup-worktree.sh"
  echo "✔ Worktree setup complete"
  cursor "$worktree_path" || { echo "Failed to open Cursor"; return 1; }
}

_gwc_completions() {
  local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
  _describe 'branch' branches
}
compdef _gwc_completions gwc

gwd() {
  [[ -z "$1" ]] && { echo "Usage: gwd <branch-name>"; return 1; }
  local worktree_path="/Users/philip/work/worktrees/$1"
  local project_name="$1"
  [[ ! -d "$worktree_path" ]] && { echo "Worktree not found: $worktree_path"; return 1; }
  local slot_file="${DEV_STACKS_DIR:-$HOME/work/.dev-stacks}/$project_name/worktree-slot"
  if [ -f "$slot_file" ]; then
    (cd "$worktree_path" && /Users/philip/.config/dev/dev.sh nuke)
    local containers=$(docker ps -q --filter "label=com.docker.compose.project=$project_name" 2>/dev/null)
    [ -n "$containers" ] && docker wait "$containers" >/dev/null 2>&1
  fi
  git -C "$worktree_path" checkout -- . && git -C "$worktree_path" clean -fd && git worktree remove "$worktree_path"
}

_gwd_completions() {
  local dir="/Users/philip/work/worktrees"
  local worktrees=(${(@f)"$(ls "$dir" 2>/dev/null)"})
  _describe 'worktree' worktrees
}
compdef _gwd_completions gwd

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
