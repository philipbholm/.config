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
frontend_files=()
declare -A service_files

while IFS= read -r file; do
  if [[ "$file" == apps/main-frontend/* ]]; then
    has_frontend=true
    # Only track lintable files
    if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
      frontend_files+=("$file")
    fi
  elif [[ "$file" == services/* ]]; then
    service=$(echo "$file" | cut -d'/' -f2)
    if [[ ! " ${changed_services[*]} " =~ " $service " ]]; then
      changed_services+=("$service")
    fi
    # Only track lintable files
    if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
      service_files[$service]+="$file "
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

  if [[ "$changed_only" == true && ${#frontend_files[@]} -gt 0 ]]; then
    echo "Running eslint on changed files..."
    # Convert to paths relative to frontend
    relative_files=()
    for f in "${frontend_files[@]}"; do
      relative_files+=("$monorepo_root/$f")
    done
    if ! npx eslint --fix "${relative_files[@]}"; then
      failed=true
    fi
    if [[ "$failed" != true ]]; then
      echo "Running prettier on changed files..."
      if ! npx prettier --write "${relative_files[@]}"; then
        failed=true
      fi
    fi
  else
    echo "Running lint:fix..."
    if ! npm run lint:fix; then
      failed=true
    fi
  fi

  if [[ "$failed" != true ]]; then
    echo "Running build..."
    if ! npm run build; then
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

  if [[ "$changed_only" == true && -n "${service_files[$service]:-}" ]]; then
    echo "Running eslint on changed files..."
    # Convert space-separated string to array and make paths absolute
    files_to_lint=()
    for f in ${(s: :)service_files[$service]}; do
      files_to_lint+=("$monorepo_root/$f")
    done
    if ! npx eslint --fix "${files_to_lint[@]}"; then
      failed=true
      continue
    fi
    echo "Running prettier on changed files..."
    if ! npx prettier --write "${files_to_lint[@]}"; then
      failed=true
      continue
    fi
  else
    echo "Running lint:fix..."
    if ! npm run lint:fix; then
      failed=true
      continue
    fi
  fi

  # Try build-ts first, fall back to build
  echo "Running build..."
  if npm run build-ts 2>/dev/null; then
    :
  elif ! npm run build; then
    failed=true
    continue
  fi
done

if [[ "$failed" == true ]]; then
  echo ""
  echo "❌ Some checks failed!"
  exit 1
fi

echo ""
echo "✅ All checks passed!"
