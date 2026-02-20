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

failed=()

cd "$monorepo_root" || exit 1

# --- Spinner helper ---
# Runs a command silently with a spinner. On failure, prints captured output.
run_step() {
  local label="$1"
  shift
  local log_file=$(mktemp)
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  # Run command in background
  eval "$@" > "$log_file" 2>&1 &
  local pid=$!

  # Show spinner
  while kill -0 $pid 2>/dev/null; do
    printf "\r  ${spin:$i:1} %s" "$label"
    i=$(( (i + 1) % ${#spin} ))
    sleep 0.1
  done
  wait $pid
  local exit_code=$?
  printf "\r\033[K"

  if [[ $exit_code -ne 0 ]]; then
    echo "❌ $label"
    cat "$log_file"
    echo ""
    rm -f "$log_file"
    return 1
  fi

  echo "✔ $label"
  rm -f "$log_file"
  return 0
}

# --- Detect changes ---

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
    if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
      frontend_files+=("$file")
    fi
  elif [[ "$file" == services/* ]]; then
    service=$(echo "$file" | cut -d'/' -f2)
    if [[ ! " ${changed_services[*]} " =~ " $service " ]]; then
      changed_services+=("$service")
    fi
    if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
      service_files[$service]+="$file "
    fi
  fi
done <<< "$changed_files"

if [[ "$has_frontend" == false && ${#changed_services[@]} -eq 0 ]]; then
  echo "No changes detected in services or frontend"
  exit 0
fi

# --- Frontend checks ---

if [[ "$has_frontend" == true ]]; then
  cd "$monorepo_root/apps/main-frontend"

  if [[ "$changed_only" == true && ${#frontend_files[@]} -gt 0 ]]; then
    relative_files=()
    for f in "${frontend_files[@]}"; do
      relative_files+=("$monorepo_root/$f")
    done
    if ! run_step "Frontend: lint (changed files)" "npx eslint --fix ${(q)relative_files[@]}"; then
      failed+=("Frontend: lint")
    fi
    if ! run_step "Frontend: format (changed files)" "npx prettier --write ${(q)relative_files[@]}"; then
      failed+=("Frontend: format")
    fi
  else
    if ! run_step "Frontend: lint" "npm run lint:fix"; then
      failed+=("Frontend: lint")
    fi
  fi

  if ! run_step "Frontend: build" "npm run build"; then
    failed+=("Frontend: build")
  fi
fi

# --- Service checks ---

for service in "${changed_services[@]}"; do
  service_path="$monorepo_root/services/$service"

  if [[ ! -d "$service_path" ]]; then
    echo "Warning: Service directory not found: $service_path"
    continue
  fi

  cd "$service_path"

  if [[ "$changed_only" == true && -n "${service_files[$service]:-}" ]]; then
    files_to_lint=()
    for f in ${(s: :)service_files[$service]}; do
      files_to_lint+=("$monorepo_root/$f")
    done
    if ! run_step "$service: lint (changed files)" "npx eslint --fix ${(q)files_to_lint[@]}"; then
      failed+=("$service: lint")
    fi
    if ! run_step "$service: format (changed files)" "npx prettier --write ${(q)files_to_lint[@]}"; then
      failed+=("$service: format")
    fi
  else
    if ! run_step "$service: lint" "npm run lint:fix"; then
      failed+=("$service: lint")
    fi
  fi

  if ! run_step "$service: build" "npm run build-ts 2>/dev/null || npm run build"; then
    failed+=("$service: build")
  fi
done

# --- Summary ---

echo ""
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "❌ Failed: ${failed[*]}"
  exit 1
fi

echo "✅ All checks passed!"
