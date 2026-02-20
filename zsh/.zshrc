# General aliases
alias ls='ls --color'
alias ll='ls -lah --color'

# Git aliases
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

# Work
export POSTGRES_URL=postgres://postgres:postgres@localhost:5432/registries
alias wtu='notify /Users/philip/.config/dev/run-worktree.sh --up'
alias wtr='/Users/philip/.config/dev/run-worktree.sh --start'
alias wts='/Users/philip/.config/dev/run-worktree.sh --stop'
alias wtn='notify /Users/philip/.config/dev/run-worktree.sh --nuke'

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
  # Remove localhost line from root CLAUDE.local.md (not relevant for worktrees)
  sed -i '' '/App runs at http:\/\/localhost:3001\/en\/registries/d' "$worktree_path/CLAUDE.local.md"
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
gwd() {
  [[ -z "$1" ]] && { echo "Usage: gwd <branch-name>"; return 1; }
  local worktree_path="/Users/philip/work/worktrees/$1"
  local project_name="$1"
  [[ ! -d "$worktree_path" ]] && { echo "Worktree not found: $worktree_path"; return 1; }
  local slot_file="${WORKTREE_TMP_DIR:-$HOME/work/tmp/dev-stacks}/$project_name/worktree-slot"
  if [ -f "$slot_file" ]; then
    (cd "$worktree_path" && /Users/philip/.config/dev/run-worktree.sh --nuke)
    local containers=$(docker ps -q --filter "label=com.docker.compose.project=$project_name" 2>/dev/null)
    [ -n "$containers" ] && docker wait "$containers" >/dev/null 2>&1
  fi
  git -C "$worktree_path" checkout -- . && git -C "$worktree_path" clean -fd && git worktree remove "$worktree_path"
}

_gwc_completions() {
  local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
  _describe 'branch' branches
}

_gwd_completions() {
  local dir="/Users/philip/work/worktrees"
  local worktrees=(${(@f)"$(ls "$dir" 2>/dev/null)"})
  _describe 'worktree' worktrees
}

prisma() {
  local monorepo_root
  monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: Not inside a git repository"
    return 1
  }
  local project_name slot worktree_slot_file
  project_name="$(basename "$monorepo_root")"
  worktree_slot_file="${DEV_STACKS_DIR:-$HOME/work/tmp/dev-stacks}/$project_name/worktree-slot"
  if [[ -f "$worktree_slot_file" ]]; then
    slot=$(cat "$worktree_slot_file")
  else
    slot=0
  fi
  local port=$((5432 + slot * 100))
  POSTGRES_URL="postgresql://postgres:postgres@localhost:$port/registries" \
    npx prisma studio --schema="$monorepo_root/services/registries/prisma/schema.prisma"
}

verify() {
  # Determine repo root from current directory
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    echo "Error: not inside a git repository"
    return 1
  }

  local repo_name=$(basename "$repo_root")
  local dev_stack_dir="$HOME/work/tmp/dev-stacks/$repo_name"
  local is_worktree=false
  local compose_args=""

  # Check if this is a worktree (has a worktree-slot file)
  if [[ -f "$dev_stack_dir/worktree-slot" ]]; then
    is_worktree=true
    compose_args="COMPOSE_PROJECT_NAME=$repo_name docker compose -f $repo_root/docker-compose.yml -f $dev_stack_dir/docker-compose.worktree.yml"
  fi

  local failed=()

  echo "=== Frontend: lint ==="
  (cd "$repo_root/apps/main-frontend" && npm run lint:fix) || failed+=(frontend-lint)

  echo ""
  echo "=== Frontend: type check ==="
  (cd "$repo_root/apps/main-frontend" && npm run build-ts) || failed+=(frontend-types)

  echo ""
  echo "=== Frontend: tests ==="
  (cd "$repo_root/apps/main-frontend" && npm run test) || failed+=(frontend-tests)

  echo ""
  echo "=== Registries: lint ==="
  (cd "$repo_root/services/registries" && npm run lint:fix) || failed+=(registries-lint)

  echo ""
  echo "=== Registries: type check ==="
  (cd "$repo_root/services/registries" && npm run build-ts) || failed+=(registries-types)

  echo ""
  echo "=== Registries: tests ==="
  if $is_worktree; then
    eval "$compose_args exec -e POSTGRES_URL=postgresql://postgres:postgres@postgres:5432/registries-test registries npx jest --runInBand" || failed+=(registries-tests)
  else
    (cd "$repo_root/services/registries" && npm run test) || failed+=(registries-tests)
  fi

  echo ""
  if [[ ${#failed[@]} -eq 0 ]]; then
    echo "=== All checks passed ==="
  else
    echo "=== FAILED: ${failed[*]} ==="
    return 1
  fi
}

seed() {
  local worktree_root="/Users/philip/work/worktrees"
  local worktree_tmp="/Users/philip/work/tmp/dev-stacks"
  local cwd="$PWD"
  local compose_args=()

  if [[ "$cwd" == "$worktree_root/"* ]]; then
    local name="${cwd#$worktree_root/}"
    name="${name%%/*}"
    compose_args=(--project-name="$name" -f "$worktree_root/$name/docker-compose.yml" -f "$worktree_tmp/$name/docker-compose.worktree.yml")
  fi

  for target in icd10 atc; do
    echo "Seeding $target..."
    command docker compose ${compose_args[@]} exec -e POSTGRES_URL="postgresql://postgres:postgres@postgres:5432/registries" registries npm run "seed-$target"
  done
}

# Paths
export PATH="/usr/local/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$PATH:$HOME/go/bin"
export PATH="$HOME/bin:$PATH"
export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"
export PATH="$PATH:/Users/philip/.modular/bin"
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk@17/include"
export PATH="/Users/philip/.duckdb/cli/latest:$PATH"
export PATH="/opt/homebrew/opt/gradle@8/bin:$PATH"
export PATH=/Users/philip/.opencode/bin:$PATH
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="$PATH:$(npm config get prefix)/bin"
export PATH="$HOME/.local/bin:$PATH"

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Environment variables
# export PS1='%~ %# '  # Full path
export PS1='%c %# '  # Current directory
# Disable claude telementry
export DISABLE_TELEMETRY=1
export DISABLE_ERROR_REPORTING=1
# Disable playwright warnings
export NODE_NO_WARNINGS=1

# Load secrets (API keys, tokens)
[ -f "$HOME/.config/zsh/.zsh_secrets" ] && source "$HOME/.config/zsh/.zsh_secrets"

# Functions
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

rebuild() {
  /Users/philip/.config/dev/rebuild.sh "$@"
}

_rebuild_completions() {
  local services=("frontend" "registries" "studies" "admin" "codelist")
  _describe 'service' services
}
compdef _rebuild_completions rebuild

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
compdef _gwc_completions gwc
compdef _gwd_completions gwd

shell() {
  /Users/philip/.config/dev/shell.sh "$@"
}

_shell_completions() {
  local services=("frontend" "registries" "studies" "admin" "codelist" "auth")
  _describe 'service' services
}
compdef _shell_completions shell

db() {
  /Users/philip/.config/dev/db.sh "$@"
}

_db_completions() {
  local services=("admin" "studies" "codelist" "registries")
  _describe 'service' services
}
compdef _db_completions db

check() {
  /Users/philip/.config/dev/check.sh "$@"
}

_check_completions() {
  local branches=($(git branch --format='%(refname:short)' 2>/dev/null))
  _describe 'branch' branches
}
compdef _check_completions check

run-main() {
  /Users/philip/.config/dev/run-main.sh "$@"
}

_run_main_completions() {
  local commands=("--up" "--stop" "--start" "--down" "--nuke" "--rebuild" "--help")
  _describe 'command' commands
}
compdef _run_main_completions run-main

run-worktree() {
  /Users/philip/.config/dev/run-worktree.sh "$@"
}

_run_worktree_completions() {
  local commands=("--up" "--stop" "--start" "--down" "--nuke" "--status" "--rebuild" "--help")
  _describe 'command' commands
}
compdef _run_worktree_completions run-worktree

# zsh-autosuggestions - History-based autocomplete
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# Bind Shift+Tab to accept autosuggestion
# First, unbind any existing Shift+Tab bindings that might conflict
bindkey -r '\e[Z' 2>/dev/null
bindkey -r '^[[Z' 2>/dev/null

# Bind Shift+Tab to accept autosuggestion in all keymaps
bindkey '\e[Z' autosuggest-accept
bindkey '^[[Z' autosuggest-accept
bindkey -M viins '\e[Z' autosuggest-accept
bindkey -M viins '^[[Z' autosuggest-accept
bindkey -M emacs '\e[Z' autosuggest-accept
bindkey -M emacs '^[[Z' autosuggest-accept

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
unsetopt SHARE_HISTORY
unsetopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE
