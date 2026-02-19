#!/usr/bin/env zsh
set -euo pipefail

# Parse args: tests [slot]
slot="${1:-0}"

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ $? -ne 0 ]]; then
  echo "Error: Not inside a git repository"
  exit 1
fi

cd "$monorepo_root" || exit 1

# Determine ports from slot
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

# --- Frontend unit tests ---

cd "$monorepo_root/apps/main-frontend"
run_step "Frontend: unit tests" "npx vitest run --project=unit" || exit 1

# --- Registries tests ---

cd "$monorepo_root/services/registries"
run_step "Registries: tests" "POSTGRES_URL=postgresql://postgres:postgres@localhost:$postgres_port/registries-test npx jest --testPathIgnorePatterns='e2e' --runInBand" || exit 1

# --- E2E tests (Playwright) ---

cd "$monorepo_root/apps/main-frontend"
run_step "Frontend: e2e tests" "BASE_URL=http://localhost:$frontend_port E2E_API_URL=http://localhost:$api_port npx playwright test 'src/app/.*/registries/.*\.spec\.tsx'" || exit 1

# --- Summary ---

echo ""
echo "✅ All tests passed!"
