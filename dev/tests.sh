#!/usr/bin/env zsh
set -euo pipefail

### tests.sh — Run tests for the Ledidi monorepo
###
### Usage:
###   tests [suites...] [-- extra-args]
###
### Suites:
###   frontend     Frontend unit tests (Vitest)
###   registries   Registries service tests (Jest)
###   e2e          Frontend E2E tests (Playwright)
###
### With no suite arguments, all suites run. Extra args after -- are
### forwarded to the underlying test runner.
###
### Examples:
###   tests                            Run all test suites
###   tests frontend                   Only frontend unit tests
###   tests registries e2e             Registries + E2E
###   tests frontend -- src/app/path   Frontend tests for specific path
###   tests registries -- --verbose    Registries with extra Jest flags

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Error: Not inside a git repository"
  exit 1
}

cd "$monorepo_root" || exit 1

# --- Parse arguments ---

suites=()
passthrough_args=()
parsing_suites=true

for arg in "$@"; do
  if [[ "$arg" == "--" ]]; then
    parsing_suites=false
    continue
  fi
  if $parsing_suites; then
    suites+=("$arg")
  else
    passthrough_args+=("$arg")
  fi
done

# Default: run all suites
if [[ ${#suites[@]} -eq 0 ]]; then
  suites=(frontend registries e2e)
fi

# Validate suite names
valid_suites=(frontend registries e2e)
for s in "${suites[@]}"; do
  if [[ ! " ${valid_suites[*]} " =~ " $s " ]]; then
    echo "Unknown suite: $s"
    echo "Valid suites: ${valid_suites[*]}"
    exit 1
  fi
done

# --- Determine ports from worktree slot ---

project_name="$(basename "$monorepo_root")"
worktree_slot_file="${DEV_STACKS_DIR:-$HOME/work/tmp/dev-stacks}/$project_name/worktree-slot"
if [[ -f "$worktree_slot_file" ]]; then
  slot=$(cat "$worktree_slot_file")
else
  slot=0
fi
offset=$((slot * 100))
postgres_port=$((5432 + offset))
frontend_port=$((3001 + offset))
api_port=$((4000 + offset))

# --- Streaming test runner ---
run_step() {
  local label="$1"
  shift
  local log_file=$(mktemp)

  echo "=== $label ==="
  export FORCE_COLOR=1
  eval "$@" 2>&1 | tee "$log_file" | grep --line-buffered -E '(✓|✕|×|✘|PASS |FAIL |Tests:|Test Suites:|Test Files|Tests |^\s+\d+ (passed|failed))'
  local exit_code=${pipestatus[1]}

  if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo "Full output: $log_file"
    return 1
  fi

  rm -f "$log_file"
  echo ""
  return 0
}

extra="${passthrough_args[*]:-}"
failed=false

# --- Frontend unit tests ---

if (( ${suites[(Ie)frontend]} )); then
  cd "$monorepo_root/apps/main-frontend"
  if ! run_step "Frontend: unit tests" "npx vitest run --project=unit $extra"; then
    failed=true
  fi
fi

# --- Registries tests ---

if (( ${suites[(Ie)registries]} )); then
  cd "$monorepo_root/services/registries"
  if ! run_step "Registries: tests" "POSTGRES_URL=postgresql://postgres:postgres@localhost:$postgres_port/registries-test npx jest --testPathIgnorePatterns='e2e' --runInBand $extra"; then
    failed=true
  fi
fi

# --- E2E tests (Playwright) ---

if (( ${suites[(Ie)e2e]} )); then
  cd "$monorepo_root/apps/main-frontend"
  if ! run_step "Frontend: e2e tests" "FRONTEND_BASE_URL=http://localhost:$frontend_port E2E_API_URL=http://localhost:$api_port npx playwright test 'src/app/.*/registries/.*\.spec\.tsx' $extra"; then
    failed=true
  fi
fi

# --- Summary ---

echo ""
if [[ "$failed" == true ]]; then
  echo "❌ Some tests failed!"
  exit 1
fi

echo "✅ All tests passed!"
