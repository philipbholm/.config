#!/bin/bash
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "$REPO_DIR/switch-theme.sh"

TEST_DIR=$(mktemp -d)
trap 'rm -r "$TEST_DIR"' EXIT
THEME_DIR="$REPO_DIR/alacritty/themes"
ACTIVE_THEME="$TEST_DIR/active_theme.toml"
TEST_EVENTS="$TEST_DIR/events"
TEST_PROCESSES=""
TEST_PS_STATUS=0

ps() {
  printf '%s\n' "$TEST_PROCESSES"
  return "$TEST_PS_STATUS"
}

date() { echo "$TEST_HOUR"; }

defaults() {
  if [[ "$1" == read ]]; then
    echo "$TEST_STYLE"
  else
    echo defaults >> "$TEST_EVENTS"
  fi
}

osascript() {
  case "$2" in
    *'dark mode to true') TEST_STYLE=Dark ;;
    *'dark mode to false') TEST_STYLE=Light ;;
    *) echo "Unexpected appearance command: $2" >&2; return 1 ;;
  esac
  echo appearance >> "$TEST_EVENTS"
}

launchctl() { echo borders >> "$TEST_EVENTS"; }
touch() { echo reload >> "$TEST_EVENTS"; }
refresh_tmux_colors() { echo colors >> "$TEST_EVENTS"; }

assert_events() {
  local EXPECTED="$1"
  if [[ "$(cat "$TEST_EVENTS")" != "$EXPECTED" ]]; then
    echo "Unexpected theme operations:" >&2
    cat "$TEST_EVENTS" >&2
    exit 1
  fi
}

for TEST_COMMAND in \
  codex \
  /Users/example/.local/bin/claude \
  /Users/example/.local/bin/agent \
  /Users/example/.local/bin/cursor-agent \
  /Users/example/.local/share/cursor-agent/versions/example/node; do
  for TEST_TARGET in light dark; do
    if [[ "$TEST_TARGET" == light ]]; then
      TEST_SOURCE=dark TEST_STYLE=Dark TEST_HOUR=7
    else
      TEST_SOURCE=light TEST_STYLE=Light TEST_HOUR=18
    fi
    cp "$THEME_DIR/$TEST_SOURCE.toml" "$ACTIVE_THEME"
    : > "$TEST_EVENTS"
    TEST_PROCESSES="ttys001 $TEST_COMMAND"

    main
    cmp "$THEME_DIR/$TEST_SOURCE.toml" "$ACTIVE_THEME"
    assert_events $'defaults\nappearance\nborders'

    # Manual requests also preserve the palette while an agent is running.
    : > "$TEST_EVENTS"
    main "$TEST_TARGET"
    cmp "$THEME_DIR/$TEST_SOURCE.toml" "$ACTIVE_THEME"
    assert_events $'defaults\nappearance\nborders'

    # Background app servers and unrelated terminal processes do not defer it.
    TEST_PROCESSES=$'?? /Applications/ChatGPT.app/Contents/Resources/codex\n?? claude\nttys001 node\nttys002 -zsh'
    : > "$TEST_EVENTS"
    main
    cmp "$THEME_DIR/$TEST_TARGET.toml" "$ACTIVE_THEME"
    assert_events $'reload\ncolors'

    : > "$TEST_EVENTS"
    main
    assert_events ''
    echo "PASS: $TEST_COMMAND defers $TEST_TARGET and catches up after exit"
  done
done

cp "$THEME_DIR/dark.toml" "$ACTIVE_THEME"
TEST_HOUR=7 TEST_STYLE=Light TEST_PS_STATUS=1
: > "$TEST_EVENTS"
main 2> "$TEST_DIR/error"
cmp "$THEME_DIR/dark.toml" "$ACTIVE_THEME"
assert_events ''
[[ -s "$TEST_DIR/error" ]]
echo "PASS: a process inspection failure preserves the terminal theme"
