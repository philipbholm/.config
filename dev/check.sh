#!/usr/bin/env zsh
set -euo pipefail

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ $? -ne 0 ]]; then
  echo "Error: Not inside a git repository"
  exit 1
fi

base_branch="${1:-master}"
failed=false

cd "$monorepo_root" || exit 1

# Determine postgres port from worktree slot
project_name="$(basename "$monorepo_root")"
worktree_slot_file="${DEV_STACKS_DIR:-$HOME/work/tmp/dev-stacks}/$project_name/worktree-slot"
if [[ -f "$worktree_slot_file" ]]; then
  slot=$(cat "$worktree_slot_file")
  postgres_port=$((5432 + slot * 100))
else
  postgres_port=5432
fi

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

while IFS= read -r file; do
  if [[ "$file" == apps/main-frontend/* ]]; then
    has_frontend=true
    if [[ "$file" == *.e2e.ts || "$file" == *e2e/*.ts ]]; then
      e2e_tests+=("${file#apps/main-frontend/}")
    fi
  elif [[ "$file" == services/* ]]; then
    service=$(echo "$file" | cut -d'/' -f2)
    if [[ ! " ${changed_services[*]} " =~ " $service " ]]; then
      changed_services+=("$service")
    fi
    if [[ "$file" == *.e2e.ts || "$file" == *e2e/*.ts ]]; then
      e2e_tests+=("$file")
    fi
  fi
done <<< "$changed_files"

if [[ "$has_frontend" == false && ${#changed_services[@]} -eq 0 ]]; then
  echo "No changes detected in services or frontend"
  exit 0
fi

# Frontend checks
if [[ "$has_frontend" == true ]]; then
  echo ""
  echo "=== Checking frontend ==="
  cd "$monorepo_root/apps/main-frontend"

  echo "Running lint:fix..."
  if ! npm run lint:fix; then
    failed=true
  fi

  if [[ "$failed" != true ]]; then
    echo "Running build..."
    if ! npm run build; then
      failed=true
    fi
  fi

  if [[ "$failed" != true ]]; then
    echo "Running unit tests..."
    if ! npx vitest run --project=unit; then
      failed=true
    fi
  fi

  if [[ "$failed" != true ]]; then
    echo "Running integration tests..."
    if ! npx vitest run --project=integration; then
      failed=true
    fi
  fi
fi

# Service checks
for service in "${changed_services[@]}"; do
  service_path="$monorepo_root/services/$service"

  if [[ ! -d "$service_path" ]]; then
    echo "Warning: Service directory not found: $service_path"
    continue
  fi

  echo ""
  echo "=== Checking $service ==="
  cd "$service_path"

  echo "Running lint:fix..."
  if ! npm run lint:fix; then
    failed=true
    continue
  fi

  # Try build-ts first, fall back to build
  echo "Running build..."
  if npm run build-ts 2>/dev/null; then
    :
  elif ! npm run build; then
    failed=true
    continue
  fi

  echo "Running unit tests..."
  if ! POSTGRES_URL="postgresql://postgres:postgres@localhost:$postgres_port/${service}-test" npx jest --testPathIgnorePatterns='integration|e2e' --runInBand; then
    failed=true
    continue
  fi

  echo "Running integration tests..."
  if ! POSTGRES_URL="postgresql://postgres:postgres@localhost:$postgres_port/${service}-test" npx jest --testPathPattern='integration' --runInBand; then
    failed=true
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
  echo "❌ Some checks failed!"
  exit 1
fi

echo ""
echo "✅ All checks passed!"
