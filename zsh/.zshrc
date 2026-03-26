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
export PATH="/Users/philip/.browser-use/bin:$PATH"

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

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
# export LEFTHOOK=0
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

sync-claude-md() {
  local template="$HOME/.config/dev/claude/ledidi-monorepo/CLAUDE.local.md"
  if [[ ! -f "$template" ]]; then
    echo "Template not found: $template" >&2
    return 1
  fi

  local -a targets=()

  # Main repo (slot 0)
  local main_repo="$HOME/work/ledidi-monorepo"
  if [[ -d "$main_repo" ]]; then
    targets+=("$main_repo:0")
  fi

  # Worktrees with active dev stacks (have a slot file)
  for wt in "$HOME/work/worktrees"/*/; do
    [[ -d "$wt" ]] || continue
    local name="${wt:t}"
    local slot_file="$HOME/work/.dev-stacks/$name/worktree-slot"
    if [[ -f "$slot_file" ]]; then
      targets+=("${wt%/}:$(< "$slot_file")")
    fi
  done

  if (( ${#targets} == 0 )); then
    echo "No targets found"
    return 0
  fi

  local count=0
  for entry in "${targets[@]}"; do
    local target="${entry%%:*}"
    local slot="${entry##*:}"
    local offset=$(( slot * 100 ))
    local dest="$target/CLAUDE.local.md"

    cp "$template" "$dest"

    sed -i '' \
      -e "s|{{FRONTEND_PORT}}|$(( 3003 + offset ))|g" \
      -e "s|{{ROUTER_PORT}}|$(( 4000 + offset ))|g" \
      -e "s|{{POSTGRES_PORT}}|$(( 5432 + offset ))|g" \
      -e "s|{{CODELIST_PORT}}|$(( 4005 + offset ))|g" \
      -e "s|{{CODELIST_GRPC_PORT}}|$(( 50005 + offset ))|g" \
      -e "s|{{REGISTRIES_PORT}}|$(( 4006 + offset ))|g" \
      -e "s|{{REGISTRIES_GRPC_PORT}}|$(( 50006 + offset ))|g" \
      -e "s|{{AGENT_PORT}}|$(( 4007 + offset ))|g" \
      "$dest"

    (( count++ ))
    echo "  ✓ ${target##*/} (slot $slot)"
  done

  echo "Synced $count workspace(s)"
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
