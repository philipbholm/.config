#!/usr/bin/env zsh
set -euo pipefail

# Parse flags
changed_only=false
base_branch=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--changed) changed_only=true; shift ;;
    *) base_branch="$1"; shift ;;
  esac
done
base_branch="${base_branch:-master}"

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ $? -ne 0 ]]; then
  echo "Error: Not inside a git repository"
  exit 1
fi

failed=false

cd "$monorepo_root" || exit 1

# Determine ports from worktree slot
project_name="$(basename "$monorepo_root")"
worktree_slot_file="${DEV_STACKS_DIR:-$HOME/work/tmp/dev-stacks}/$project_name/worktree-slot"
if [[ -f "$worktree_slot_file" ]]; then
  slot=$(cat "$worktree_slot_file")
  offset=$((slot * 100))
  postgres_port=$((5432 + offset))
  frontend_port=$((3001 + offset))
  api_port=$((4000 + offset))
else
  postgres_port=5432
  frontend_port=3001
  api_port=4000
fi

export E2E_BASE_URL="http://localhost:$frontend_port"
export E2E_API_URL="http://localhost:$api_port"

echo "Checking for changed files compared to $base_branch..."

changed_files=""
if git rev-parse --verify "$base_branch" >/dev/null 2>&1; then
  changed_files=$(git diff --name-only "$base_branch"...HEAD 2>/dev/null)
  if [[ -z "$changed_files" ]]; then
    changed_files=$(git diff --name-only "$base_branch" 2>/dev/null)
  fi
else
  echo "Error: Branch '$base_branch' not found"
  exit 1
fi

if [[ -z "$changed_files" ]]; then
  echo "No changed files found compared to $base_branch"
  exit 0
fi

# Detect which areas have changes
has_frontend=false
changed_services=()
e2e_tests=()
frontend_files=()
declare -A service_files

while IFS= read -r file; do
  if [[ "$file" == apps/main-frontend/* ]]; then
    has_frontend=true
    if [[ "$file" == *.e2e.ts || "$file" == *e2e/*.ts ]]; then
      e2e_tests+=("${file#apps/main-frontend/}")
    fi
    # Track test-related files for --changed mode
    if [[ "$file" == *.ts || "$file" == *.tsx ]]; then
      frontend_files+=("$monorepo_root/$file")
    fi
  elif [[ "$file" == services/* ]]; then
    service=$(echo "$file" | cut -d'/' -f2)
    if [[ ! " ${changed_services[*]} " =~ " $service " ]]; then
      changed_services+=("$service")
    fi
    if [[ "$file" == *.e2e.ts || "$file" == *e2e/*.ts ]]; then
      e2e_tests+=("$file")
    fi
    # Track test-related files for --changed mode
    if [[ "$file" == *.ts ]]; then
      service_files[$service]+="$monorepo_root/$file "
    fi
  fi
done <<< "$changed_files"

if [[ "$has_frontend" == false && ${#changed_services[@]} -eq 0 ]]; then
  echo "No changes detected in services or frontend"
  exit 0
fi

# Frontend tests
if [[ "$has_frontend" == true ]]; then
  echo ""
  echo "=== Testing frontend ==="
  cd "$monorepo_root/apps/main-frontend"

  if [[ "$changed_only" == true && ${#frontend_files[@]} -gt 0 ]]; then
    echo "Running unit tests for changed files..."
    if ! npx vitest run --project=unit --passWithNoTests "${frontend_files[@]}"; then
      failed=true
    fi

    if [[ "$failed" != true ]]; then
      echo "Running integration tests for changed files..."
      if ! npx vitest run --project=integration --passWithNoTests "${frontend_files[@]}"; then
        failed=true
      fi
    fi
  else
    echo "Running unit tests..."
    if ! npx vitest run --project=unit; then
      failed=true
    fi

    if [[ "$failed" != true ]]; then
      echo "Running integration tests..."
      if ! npx vitest run --project=integration; then
        failed=true
      fi
    fi
  fi
fi

# Service tests
for service in "${changed_services[@]}"; do
  service_path="$monorepo_root/services/$service"

  if [[ ! -d "$service_path" ]]; then
    echo "Warning: Service directory not found: $service_path"
    continue
  fi

  echo ""
  echo "=== Testing $service ==="
  cd "$service_path"

  if [[ "$changed_only" == true && -n "${service_files[$service]:-}" ]]; then
    # Convert space-separated string to array
    files_to_test=()
    for f in ${(s: :)service_files[$service]}; do
      files_to_test+=("$f")
    done

    echo "Running unit tests for changed files..."
    if ! POSTGRES_URL="postgresql://postgres:postgres@localhost:$postgres_port/${service}-test" npx jest --findRelatedTests "${files_to_test[@]}" --testPathIgnorePatterns='integration|e2e' --runInBand --passWithNoTests; then
      failed=true
      continue
    fi

    echo "Running integration tests for changed files..."
    if ! POSTGRES_URL="postgresql://postgres:postgres@localhost:$postgres_port/${service}-test" npx jest --findRelatedTests "${files_to_test[@]}" --testPathPattern='integration' --runInBand --passWithNoTests; then
      failed=true
    fi
  else
    echo "Running unit tests..."
    if ! POSTGRES_URL="postgresql://postgres:postgres@localhost:$postgres_port/${service}-test" npx jest --testPathIgnorePatterns='integration|e2e' --runInBand; then
      failed=true
      continue
    fi

    echo "Running integration tests..."
    if ! POSTGRES_URL="postgresql://postgres:postgres@localhost:$postgres_port/${service}-test" npx jest --testPathPattern='integration' --runInBand; then
      failed=true
    fi
  fi
done

# Run only changed e2e tests
if [[ "$failed" != true && ${#e2e_tests[@]} -gt 0 ]]; then
  echo ""
  echo "=== Running changed e2e tests ==="
  cd "$monorepo_root"
  for e2e_test in "${e2e_tests[@]}"; do
    if [[ -f "$e2e_test" ]]; then
      echo "Running $e2e_test..."
      if ! npx jest "$e2e_test" --runInBand; then
        failed=true
      fi
    fi
  done
fi

if [[ "$failed" == true ]]; then
  echo ""
  echo "❌ Some tests failed!"
  exit 1
fi

echo ""
echo "✅ All tests passed!"
