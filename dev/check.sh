#!/bin/zsh
set -o pipefail

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ $? -ne 0 ]]; then
  echo "Error: Not inside a git repository"
  exit 1
fi

base_branch="${1:-master}"
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

frontend_files=()
typeset -A service_files

while IFS= read -r file; do
  if [[ "$file" == apps/main-frontend/* ]]; then
    frontend_files+=("$file")
  elif [[ "$file" == services/* ]]; then
    service=$(echo "$file" | cut -d'/' -f2)
    if [[ -z "${service_files[$service]}" ]]; then
      service_files[$service]="$file"
    else
      service_files[$service]="${service_files[$service]}"$'\n'"$file"
    fi
  fi
done <<< "$changed_files"

has_changes=false

if [[ ${#frontend_files[@]} -gt 0 ]]; then
  has_changes=true
  echo ""
  echo "=== Checking frontend (${#frontend_files[@]} file(s)) ==="
  if cd "$monorepo_root/apps/main-frontend"; then
    prettier_files=()
    eslint_files=()
    test_files=()

    for file in "${frontend_files[@]}"; do
      rel_file="${file#apps/main-frontend/}"
      [[ ! -f "$rel_file" ]] && continue

      if [[ "$rel_file" == *.ts || "$rel_file" == *.tsx || "$rel_file" == *.js || "$rel_file" == *.jsx ]]; then
        prettier_files+=("$rel_file")
        eslint_files+=("$rel_file")
        if [[ "$rel_file" == *.test.ts || "$rel_file" == *.test.tsx || "$rel_file" == *.spec.ts || "$rel_file" == *.spec.tsx ]]; then
          test_files+=("$rel_file")
        fi
      elif [[ "$rel_file" == *.graphql ]]; then
        prettier_files+=("$rel_file")
      fi
    done

    if [[ ${#prettier_files[@]} -gt 0 ]]; then
      echo "Fixing formatting..."
      if ! npx prettier --write "${prettier_files[@]}"; then
        failed=true
      fi
    fi

    if [[ "$failed" != true && ${#eslint_files[@]} -gt 0 ]]; then
      echo "Running eslint --fix..."
      npx eslint --fix "${eslint_files[@]}" 2>&1 | grep -vE "(WARNING: You are currently running a version of TypeScript|SUPPORTED TYPESCRIPT VERSIONS:|YOUR TYPESCRIPT VERSION:|Please only submit bug reports)"
      if [[ ${pipestatus[1]} -ne 0 ]]; then
        failed=true
      fi
    fi

    if [[ "$failed" != true && ${#test_files[@]} -gt 0 ]]; then
      echo "Running tests..."
      if ! npx vitest run --project=unit "${test_files[@]}"; then
        failed=true
      fi
    fi
  else
    failed=true
  fi
fi

for service in "${(@k)service_files}"; do
  has_changes=true
  service_path="$monorepo_root/services/$service"

  if [[ ! -d "$service_path" ]]; then
    echo "Warning: Service directory not found: $service_path"
    continue
  fi

  files_for_service="${service_files[$service]}"
  file_count=$(echo "$files_for_service" | grep -c .)

  echo ""
  echo "=== Checking $service ($file_count file(s)) ==="
  if ! cd "$service_path"; then
    failed=true
    continue
  fi

  prettier_files=()
  eslint_files=()
  test_files=()
  has_prisma=false

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    rel_file="${file#services/$service/}"
    [[ ! -f "$rel_file" ]] && continue

    if [[ "$rel_file" == prisma/*.prisma ]]; then
      has_prisma=true
    elif [[ "$rel_file" == api/*.graphql ]]; then
      prettier_files+=("$rel_file")
    elif [[ "$rel_file" == *.ts ]]; then
      prettier_files+=("$rel_file")
      eslint_files+=("$rel_file")
      if [[ "$rel_file" == *.test.ts || "$rel_file" == *.integration.test.ts ]]; then
        test_files+=("$rel_file")
      fi
    fi
  done <<< "$files_for_service"

  service_failed=false

  if [[ "$has_prisma" == true ]]; then
    echo "Running prisma lint..."
    if ! npm run lint-prisma; then
      failed=true
      service_failed=true
    fi
  fi

  if [[ "$service_failed" != true && ${#prettier_files[@]} -gt 0 ]]; then
    echo "Fixing formatting..."
    if ! npx prettier --write "${prettier_files[@]}"; then
      failed=true
      service_failed=true
    fi
  fi

  if [[ "$service_failed" != true && ${#eslint_files[@]} -gt 0 ]]; then
    echo "Running eslint --fix..."
    npx eslint --fix "${eslint_files[@]}" 2>&1 | grep -vE "(WARNING: You are currently running a version of TypeScript|SUPPORTED TYPESCRIPT VERSIONS:|YOUR TYPESCRIPT VERSION:|Please only submit bug reports)"
    if [[ ${pipestatus[1]} -ne 0 ]]; then
      failed=true
      service_failed=true
    fi
  fi

  if [[ "$service_failed" != true && ${#test_files[@]} -gt 0 ]]; then
    echo "Running tests..."
    if ! npx jest --runInBand "${test_files[@]}"; then
      failed=true
      service_failed=true
    fi
  fi
done

if [[ "$has_changes" == false ]]; then
  echo "No changes detected in services or frontend"
  exit 0
fi

if [[ "$failed" == true ]]; then
  echo ""
  echo "❌ Some checks failed!"
  exit 1
fi

echo ""
echo "✅ All checks passed!"
