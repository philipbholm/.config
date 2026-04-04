#!/usr/bin/env zsh
set -euo pipefail

### tests.sh — Run tests for the Ledidi monorepo
###
### Usage:
###   tests [-a | --all] [suites...] [-- extra-args]
###
### Flags:
###   -a, --all    Run all tests (default: only tests related to changed files)
###
### Suites:
###   frontend     Frontend unit tests (Vitest)
###   registries   Registries service tests (Vitest)
###   e2e          Frontend E2E tests (Playwright)
###
### With no suite arguments, all suites run. Extra args after -- are
### forwarded to the underlying test runner.
###
### Examples:
###   tests                            Run changed tests across all suites
###   tests --all                      Run all tests in all suites
###   tests frontend                   Only changed frontend unit tests
###   tests -a registries              All registries tests
###   tests frontend -- src/app/path   Frontend tests for specific path
###   tests registries -- --verbose    Registries with extra Vitest flags

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "Error: Not inside a git repository"
  exit 1
}

cd "$monorepo_root" || exit 1

GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Parse arguments ---

run_all=false
suites=()
passthrough_args=()
parsing_suites=true

for arg in "$@"; do
  if [[ "$arg" == "--" ]]; then
    parsing_suites=false
    continue
  fi
  if $parsing_suites; then
    case "$arg" in
      -a|--all) run_all=true ;;
      *) suites+=("$arg") ;;
    esac
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
stacks_dir="${DEV_STACKS_DIR:-$HOME/work/.dev-stacks}"
worktree_slot_file="$stacks_dir/$project_name/worktree-slot"

if [[ -f "$monorepo_root/.git" ]]; then
  # Worktree — .git is a file, not a directory
  if [[ -f "$worktree_slot_file" ]]; then
    slot=$(cat "$worktree_slot_file")
  else
    echo "Error: No slot assigned for worktree '$project_name'. Run 'dev up' first."
    exit 1
  fi
else
  # Main repo — always slot 0
  slot=0
fi
offset=$((slot * 100))
FRONTEND_BASE_PORT=3003
postgres_port=$((5432 + offset))
frontend_port=$((FRONTEND_BASE_PORT + offset))
api_port=$((4006 + offset))

# --- Collect changed files (when not --all) ---

changed_files=()
if [[ "$run_all" == false ]]; then
  base_branch=master
  branch_diff=""
  unstaged=""
  staged=""

  if git rev-parse --verify "$base_branch" >/dev/null 2>&1; then
    branch_diff=$(git diff --name-only "$base_branch"...HEAD 2>/dev/null || true)
    if [[ -z "$branch_diff" ]]; then
      branch_diff=$(git diff --name-only "$base_branch" 2>/dev/null || true)
    fi
  fi

  unstaged=$(git diff --name-only 2>/dev/null || true)
  staged=$(git diff --name-only --cached 2>/dev/null || true)

  while IFS= read -r file; do
    [[ -n "$file" ]] && changed_files+=("$file")
  done < <(printf '%s\n%s\n%s\n' "$branch_diff" "$unstaged" "$staged" | sort -u | grep -v '^$' || true)
fi

# --- Streaming test runner ---
# Uses awk instead of grep to strip ANSI codes before pattern matching,
# which prevents FORCE_COLOR=1 escape sequences from breaking matches.

run_step() {
  local label="$1"
  shift
  local log_file=$(mktemp)

  echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}$label${NC}"
  export FORCE_COLOR=1
  eval "$@" 2>&1 | tee "$log_file" | awk '{
    plain = $0
    gsub(/\033\[[0-9;]*m/, "", plain)
    if (plain ~ /[✓✕×✘]/ || plain ~ /PASS |FAIL / || plain ~ /Tests:/ || plain ~ /Test Suites:/ || plain ~ /Test Files/ || plain ~ /[0-9]+ (passed|failed)/) {
      print $0
      fflush()
    }
  }'
  local exit_code=${pipestatus[1]}

  if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo "Full output: $log_file"
    return 1
  fi

  rm -f "$log_file"
  return 0
}

run_e2e() {
  local label="$1"
  shift
  local log_file=$(mktemp)

  echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}$label${NC}"
  export FORCE_COLOR=1
  eval "$@" 2>&1 | tee "$log_file" | awk '{
    plain = $0
    gsub(/\033\[[0-9;]*m/, "", plain)
    if (plain ~ /[✓✕×✘]/ || plain ~ /[0-9]+ (passed|failed|skipped)/ || plain ~ /Running [0-9]+ test/) {
      print $0
      fflush()
    }
  }'
  local exit_code=${pipestatus[1]}

  if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo "Full output: $log_file"
    return 1
  fi

  rm -f "$log_file"
  return 0
}

extra="${passthrough_args[*]:-}"
passed_suites=()
failed_suites=()

# --- Frontend unit tests ---

if (( ${suites[(Ie)frontend]} )); then
  cd "$monorepo_root/apps/registries-frontend"
  if [[ "$run_all" == true ]]; then
    frontend_cmd="npx vitest run --project=unit $extra"
  else
    frontend_cmd="npx vitest run --project=unit --changed master $extra"
  fi
  if run_step "Frontend unit tests" "$frontend_cmd"; then
    passed_suites+=("Frontend unit tests")
  else
    failed_suites+=("Frontend unit tests")
  fi
fi

# --- Registries tests ---

if (( ${suites[(Ie)registries]} )); then
  cd "$monorepo_root/services/registries"

  if [[ "$run_all" == true ]]; then
    if run_step "Registries tests" "POSTGRES_URL=postgresql://postgres:postgres@localhost:$postgres_port/registries-test npx vitest run $extra"; then
      passed_suites+=("Registries tests")
    else
      failed_suites+=("Registries tests")
    fi
  else
    # Find test files co-located with changed source files
    registries_tests=()
    for file in "${changed_files[@]}"; do
      [[ "$file" != services/registries/src/* ]] && continue

      # If the file is itself a test file, include it
      if [[ "$file" == *.test.ts ]]; then
        [[ -f "$monorepo_root/$file" ]] && registries_tests+=("${file#services/registries/}")
        continue
      fi

      # Look for test files in the same directory
      dir=$(dirname "$file")
      for tf in "$monorepo_root/$dir"/*.test.ts(N); do
        registries_tests+=("${tf#$monorepo_root/services/registries/}")
      done
    done

    # Deduplicate
    if [[ ${#registries_tests[@]} -gt 0 ]]; then
      registries_tests=(${(u)registries_tests})
    fi

    if [[ ${#registries_tests[@]} -eq 0 ]]; then
      echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}Registries tests${NC}"
      echo -e "  ${DIM}No changed test files found${NC}"
      passed_suites+=("Registries tests (no changes)")
    else
      test_files="${registries_tests[*]}"
      if run_step "Registries tests" "POSTGRES_URL=postgresql://postgres:postgres@localhost:$postgres_port/registries-test npx vitest run $test_files $extra"; then
        passed_suites+=("Registries tests")
      else
        failed_suites+=("Registries tests")
      fi
    fi
  fi
fi

# --- E2E tests (Playwright) ---

ran_e2e=false
if (( ${suites[(Ie)e2e]} )); then
  cd "$monorepo_root/apps/registries-frontend"

  if [[ "$run_all" == true ]]; then
    ran_e2e=true
    if run_e2e "E2E tests" "FRONTEND_BASE_URL=http://localhost:$frontend_port E2E_API_URL=http://localhost:$api_port npx playwright test --reporter=list 'src/app/.*/registries/.*\.spec\.tsx' $extra"; then
      passed_suites+=("E2E tests")
    else
      failed_suites+=("E2E tests")
    fi
  else
    # Find spec files co-located with changed source files
    e2e_specs=()
    for file in "${changed_files[@]}"; do
      [[ "$file" != apps/registries-frontend/src/app/* ]] && continue

      # If the file is itself a spec file, include it
      if [[ "$file" == *.spec.tsx ]]; then
        [[ -f "$monorepo_root/$file" ]] && e2e_specs+=("${file#apps/registries-frontend/}")
        continue
      fi

      # Walk up directories looking for spec files
      dir=$(dirname "$file")
      while [[ "$dir" == apps/registries-frontend/src/app/* ]]; do
        for sf in "$monorepo_root/$dir"/*.spec.tsx(N); do
          e2e_specs+=("${sf#$monorepo_root/apps/registries-frontend/}")
        done
        dir=$(dirname "$dir")
      done
    done

    # Deduplicate
    if [[ ${#e2e_specs[@]} -gt 0 ]]; then
      e2e_specs=(${(u)e2e_specs})
    fi

    if [[ ${#e2e_specs[@]} -eq 0 ]]; then
      echo -e "\n${GREEN}${BOLD}==>${NC} ${BOLD}E2E tests${NC}"
      echo -e "  ${DIM}No changed spec files found${NC}"
      passed_suites+=("E2E tests (no changes)")
    else
      ran_e2e=true
      # Convert bracket directories to .* for Playwright regex matching
      playwright_args=()
      for spec in "${e2e_specs[@]}"; do
        playwright_args+=("$(echo "$spec" | sed 's/\[[^]]*\]/.*/g')")
      done
      spec_args="${playwright_args[*]}"
      if run_e2e "E2E tests" "FRONTEND_BASE_URL=http://localhost:$frontend_port E2E_API_URL=http://localhost:$api_port npx playwright test --reporter=list $spec_args $extra"; then
        passed_suites+=("E2E tests")
      else
        failed_suites+=("E2E tests")
      fi
    fi
  fi
fi

# --- Summary ---

# Start Playwright report server in background (prints URL, opens browser)
report_pid=""
if $ran_e2e; then
  cd "$monorepo_root/apps/registries-frontend"
  npx playwright show-report &
  report_pid=$!
  sleep 1
fi

echo ""
for s in "${passed_suites[@]}"; do
  echo -e "  ${GREEN}✔${NC} $s"
done
for s in "${failed_suites[@]}"; do
  echo -e "  ${RED}✘${NC} $s"
done

final_exit=0
echo ""
if [[ ${#failed_suites[@]} -gt 0 ]]; then
  echo -e "${RED}${BOLD}❌ Some tests failed!${NC}"
  final_exit=1
else
  echo -e "${GREEN}${BOLD}✅ All tests passed!${NC}"
fi

# Keep alive while report server is running (Ctrl+C to quit)
if [[ -n "$report_pid" ]]; then
  trap "kill $report_pid 2>/dev/null; exit $final_exit" INT TERM
  wait $report_pid 2>/dev/null || true
fi

exit $final_exit
