#!/usr/bin/env zsh
set -euo pipefail

# Parse flags and targets
# Usage: check [-a|--all] [--base <branch>] [registries | registries-frontend | frontend | codelist ...]
# Default: check only changed files (vs master); auto-detects changed services/frontend from git diff
# -a, --all: check all files (not just changed)
# frontend: alias for registries-frontend
changed_only=true
base_branch="master"
targets=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--all) changed_only=false; shift ;;
    --base) base_branch="$2"; shift 2 ;;
    registries|registries-frontend|codelist) targets+=("$1"); shift ;;
    frontend) targets+=(registries-frontend); shift ;;
    *) echo "Unknown argument: $1 (valid: registries, registries-frontend, frontend, codelist)"; exit 1 ;;
  esac
done

monorepo_root=$(git rev-parse --show-toplevel 2>/dev/null)
if [[ $? -ne 0 ]]; then
  echo "Error: Not inside a git repository"
  exit 1
fi

failed=()

cd "$monorepo_root" || exit 1

# --- Helper: does this target use biome? ---
uses_biome() {
  [[ "$1" == "registries" || "$1" == "registries-frontend" ]]
}

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

# --- Docker container lookup for services without local node_modules ---
find_service_container() {
  local service="$1"
  docker ps --filter "name=.*${service}.*" --format '{{.Names}}' 2>/dev/null | grep -m1 "$service" || true
}

# --- Resolve targets ---

if [[ ${#targets[@]} -gt 0 ]]; then
  # Explicit targets given — skip git diff detection
  has_frontend=false
  changed_services=()
  frontend_files=()
  declare -A service_files

  for target in "${targets[@]}"; do
    if [[ "$target" == "registries-frontend" ]]; then
      has_frontend=true
    else
      changed_services+=("$target")
    fi
  done
else
  # Auto-detect from git diff
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

  has_frontend=false
  changed_services=()
  frontend_files=()
  declare -A service_files

  while IFS= read -r file; do
    if [[ "$file" == apps/registries-frontend/* ]]; then
      has_frontend=true
      if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
        frontend_files+=("$file")
      fi
    elif [[ "$file" == services/(registries|codelist)/* ]]; then
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
fi

# --- Frontend checks ---

if [[ "$has_frontend" == true ]]; then
  cd "$monorepo_root/apps/registries-frontend"

  if [[ "$changed_only" == true && ${#frontend_files[@]} -gt 0 ]]; then
    local prefix="apps/registries-frontend/"
    local fe_files=()
    for f in "${frontend_files[@]}"; do
      local stripped="${f#$prefix}"
      [[ -f "$stripped" ]] && fe_files+=("$stripped")
    done
    if [[ ${#fe_files[@]} -gt 0 ]]; then
      if ! run_step "Frontend: lint (changed files)" "npx biome check --write $(printf '%q ' "${fe_files[@]}")"; then
        failed+=("Frontend: lint")
      fi
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

  # Collect and fix file paths for this service
  local svc_files=()
  if [[ -n "${service_files[$service]:-}" ]]; then
    local prefix="services/$service/"
    for f in ${(s: :)service_files[$service]}; do
      local stripped="${f#$prefix}"
      [[ -f "$stripped" ]] && svc_files+=("$stripped")
    done
  fi

  # Determine if we can run locally or need Docker
  local use_docker=false
  local container=""
  if [[ ! -d "node_modules/.bin" ]]; then
    container=$(find_service_container "$service")
    if [[ -n "$container" ]]; then
      use_docker=true
    else
      echo "  ⚠  $service: skipped (no local node_modules/.bin, no running container)"
      continue
    fi
  fi

  # --- Lint ---
  if [[ ${#svc_files[@]} -gt 0 ]]; then
    if [[ "$use_docker" == true ]]; then
      if uses_biome "$service"; then
        if ! run_step "$service: lint" "docker exec $container npx biome check --write $(printf '%q ' "${svc_files[@]}")"; then
          failed+=("$service: lint")
        fi
      else
        if ! run_step "$service: lint" "docker exec $container npx eslint --fix $(printf '%q ' "${svc_files[@]}")"; then
          failed+=("$service: lint")
        fi
        if ! run_step "$service: format" "docker exec $container npx prettier --write $(printf '%q ' "${svc_files[@]}")"; then
          failed+=("$service: format")
        fi
      fi
    else
      if uses_biome "$service"; then
        if ! run_step "$service: lint" "npx biome check --write $(printf '%q ' "${svc_files[@]}")"; then
          failed+=("$service: lint")
        fi
      else
        if ! run_step "$service: lint" "npx eslint --fix $(printf '%q ' "${svc_files[@]}")"; then
          failed+=("$service: lint")
        fi
        if ! run_step "$service: format" "npx prettier --write $(printf '%q ' "${svc_files[@]}")"; then
          failed+=("$service: format")
        fi
      fi
    fi
  elif [[ "$changed_only" != true ]]; then
    if [[ "$use_docker" == true ]]; then
      if ! run_step "$service: lint" "docker exec $container npm run lint:fix"; then
        failed+=("$service: lint")
      fi
      if ! uses_biome "$service"; then
        if ! run_step "$service: format" "docker exec $container npx prettier --write ."; then
          failed+=("$service: format")
        fi
      fi
    else
      if ! run_step "$service: lint" "npm run lint:fix"; then
        failed+=("$service: lint")
      fi
      if ! uses_biome "$service"; then
        if ! run_step "$service: format" "npx prettier --write ."; then
          failed+=("$service: format")
        fi
      fi
    fi
  fi

  # --- Build ---
  if [[ "$use_docker" == true ]]; then
    if ! run_step "$service: build" "docker exec $container npm run build-ts"; then
      failed+=("$service: build")
    fi
  else
    if ! run_step "$service: build" "npm run build-ts 2>/dev/null || npm run build"; then
      failed+=("$service: build")
    fi
  fi
done

# --- Summary ---

echo ""
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "❌ Failed: ${failed[*]}"
  exit 1
fi

echo "✅ All checks passed!"
