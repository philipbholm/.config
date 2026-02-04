# Git aliases
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gb='git branch --no-column'
alias gcan='git commit --amend --no-edit'
alias gcam='git commit -a -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gl='git pull'
alias glo='git log --oneline --no-decorate'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias grb='git rebase'
alias gm='git merge'
alias grh='git reset'
alias grhh='git reset --hard'
alias gsh='git show'
alias gs='git status -sb'
alias gcm='git commit -m'
alias glc='git rev-parse HEAD | tr -d "\n" | pbcopy && echo "Copied: $(git rev-parse HEAD)"'
alias gwl='git worktree list'

# General aliases
alias ls='ls --color'
alias ll='ls -lah --color'

# Work
alias up='/Users/philip/work/ledidi-monorepo/scripts/dev --up'
alias down='/Users/philip/work/ledidi-monorepo/scripts/dev --down'
alias prisma='POSTGRES_URL=postgres://postgres:postgres@localhost:5432/registries npx prisma studio --browser chrome'
alias prisma-test='POSTGRES_URL=postgres://postgres:postgres@localhost:5432/projects-test npx prisma studio --browser chrome'
alias lint='npx prettier --write "./**/*.{ts,tsx}"'
alias tff='tofu fmt --recursive'
alias xdl='python /Users/philip/work/slack-posts/x_downloader_gui.py'
export POSTGRES_URL=postgres://postgres:postgres@localhost:5432/registries
gwc() {
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
  cursor "$worktree_path"
  # Open Cursor terminal and run claude in tmux session
  (
    sleep 3
    osascript <<EOF
      set the clipboard to "tmux new-session -s $1 'claude --dangerously-skip-permissions; exec zsh'"
      tell application "Cursor" to activate
      delay 0.3
      tell application "System Events"
        key code 17 using {command down, shift down}
        delay 0.5
        keystroke "v" using {command down}
        key code 36
      end tell
EOF
  ) &
}
gwd() {
  local worktree_path="/Users/philip/work/worktrees/$1"
  git -C "$worktree_path" checkout -- . && git -C "$worktree_path" clean -fd && git worktree remove "$worktree_path"
}

# Paths
export PATH="/usr/local/bin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
export PATH="$PATH:$HOME/go/bin"
export PATH="$HOME/bin:$PATH"
export PATH="$PATH:/Users/philip/.modular/bin"
# Moved after NVM init below
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"
export CPPFLAGS="-I/opt/homebrew/opt/openjdk@17/include"
export PATH="/Users/philip/.duckdb/cli/latest:$PATH"
export PATH="/opt/homebrew/opt/gradle@8/bin:$PATH"

# Home
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
export PATH="$PATH:$(npm config get prefix)/bin"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Environment variables
# export PS1='%~ %# '  # Full path
export PS1='%c %# '  # Current directory

# Disable claude telementry
export DISABLE_TELEMETRY=1
export DISABLE_ERROR_REPORTING=1

# Load secrets (API keys, tokens)
[ -f "$HOME/.config/zsh/.zsh_secrets" ] && source "$HOME/.config/zsh/.zsh_secrets"

# pyenv setup
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Functions
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

# Add ~/bin to PATH
export PATH="$HOME/bin:$PATH"
export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"
export PATH="/opt/homebrew/opt/postgresql@17/bin:$PATH"
