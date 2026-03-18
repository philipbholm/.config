#!/usr/bin/env zsh
set -euo pipefail

# Usage: lint [-a|--all] [--base <branch>] [registries | registries-frontend | frontend | codelist ...]
# Default: lint only changed files (vs master) in registries + registries-frontend
# -a, --all: lint entire target directories (not just changed files)
# --base <branch>: compare against <branch> instead of master
# frontend: alias for registries-frontend

changed_only=true
base_branch=master
targets=()

# Parse flags and targets
while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--all) changed_only=false; shift ;;
    --base) base_branch="$2"; shift 2 ;;
    registries|registries-frontend|codelist) targets+=("$1"); shift ;;
    frontend) targets+=(registries-frontend); shift ;;
    *) echo "Unknown argument: $1 (valid: registries, registries-frontend, frontend, codelist)"; exit 1 ;;
  esac
done

if [[ ${#targets[@]} -eq 0 ]]; then
  targets=(registries registries-frontend)
fi

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
run_step() {
  local label="$1"
  shift
  local log_file=$(mktemp)
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0

  eval "$@" > "$log_file" 2>&1 &
  local pid=$!

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

# --- Gather changed files (when not --all) ---

frontend_files=()
declare -A service_files

if [[ "$changed_only" == true ]]; then
  changed_raw=""
  if git rev-parse --verify "$base_branch" >/dev/null 2>&1; then
    changed_raw=$(git diff --name-only "$base_branch"...HEAD 2>/dev/null)
    if [[ -z "$changed_raw" ]]; then
      changed_raw=$(git diff --name-only "$base_branch" 2>/dev/null)
    fi
  else
    echo "Error: Branch '$base_branch' not found"
    exit 1
  fi

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$file" == apps/registries-frontend/* ]]; then
      if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
        frontend_files+=("$file")
      fi
    elif [[ "$file" == services/* ]]; then
      svc=$(echo "$file" | cut -d'/' -f2)
      if [[ "$file" == *.ts || "$file" == *.tsx || "$file" == *.js || "$file" == *.jsx ]]; then
        service_files[$svc]+="$file "
      fi
    fi
  done <<< "$changed_raw"
fi

# --- Run lint + format per target ---

files=()
raw_files=""
for target in "${targets[@]}"; do
  if [[ "$target" == "registries-frontend" ]]; then
    target_dir="$monorepo_root/apps/registries-frontend"
  else
    target_dir="$monorepo_root/services/$target"
  fi

  if [[ "$changed_only" == true ]]; then
    # Determine files for this target
    files=()
    if [[ "$target" == "registries-frontend" ]]; then
      [[ ${#frontend_files[@]} -gt 0 ]] && files=("${frontend_files[@]}")
    else
      raw_files="${service_files[$target]:-}"
      [[ -n "$raw_files" ]] && files=(${(z)raw_files})
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
      echo "  (no changed files for $target, skipping)"
      continue
    fi

    # Strip monorepo-relative prefix — git diff paths are repo-rooted,
    # but lint tools run from the target directory.
    local prefix=""
    if [[ "$target" == "registries-frontend" ]]; then
      prefix="apps/registries-frontend/"
    else
      prefix="services/$target/"
    fi
    files=("${files[@]#$prefix}")

    cd "$target_dir"

    # Filter out files that no longer exist on disk (renamed or deleted in this branch)
    local existing=()
    for f in "${files[@]}"; do
      [[ -f "$f" ]] && existing+=("$f")
    done
    files=("${existing[@]}")

    if [[ ${#files[@]} -eq 0 ]]; then
      echo "  (no existing changed files for $target, skipping)"
      cd "$monorepo_root"
      continue
    fi

    # Services may lack local node_modules — run via Docker if needed
    if [[ "$target" != "registries-frontend" && ! -d "node_modules/.bin" ]]; then
      local container=$(find_service_container "$target")
      if [[ -n "$container" ]]; then
        if uses_biome "$target"; then
          if ! run_step "$target: lint" "docker exec $container npx biome check --write $(printf '%q ' "${files[@]}")"; then
            failed+=("$target: lint")
          fi
        else
          if ! run_step "$target: lint" "docker exec $container npx eslint --fix $(printf '%q ' "${files[@]}")"; then
            failed+=("$target: lint")
          fi
          if ! run_step "$target: format" "docker exec $container npx prettier --write $(printf '%q ' "${files[@]}")"; then
            failed+=("$target: format")
          fi
        fi
      else
        echo "  ⚠  $target: skipped (no local node_modules/.bin, no running container)"
      fi
    else
      if uses_biome "$target"; then
        if ! run_step "$target: lint" "npx biome check --write $(printf '%q ' "${files[@]}")"; then
          failed+=("$target: lint")
        fi
      else
        if ! run_step "$target: lint" "npx eslint --fix $(printf '%q ' "${files[@]}")"; then
          failed+=("$target: lint")
        fi
        if ! run_step "$target: format" "npx prettier --write $(printf '%q ' "${files[@]}")"; then
          failed+=("$target: format")
        fi
      fi
    fi

    cd "$monorepo_root"
  else
    cd "$target_dir"

    if [[ "$target" != "registries-frontend" && ! -d "node_modules/.bin" ]]; then
      local container=$(find_service_container "$target")
      if [[ -n "$container" ]]; then
        if ! run_step "$target: lint" "docker exec $container npm run lint:fix"; then
          failed+=("$target: lint")
        fi
        if ! uses_biome "$target"; then
          if ! run_step "$target: format" "docker exec $container npx prettier --write ."; then
            failed+=("$target: format")
          fi
        fi
      else
        echo "  ⚠  $target: skipped (no local node_modules/.bin, no running container)"
      fi
    else
      if ! run_step "$target: lint" "npm run lint:fix"; then
        failed+=("$target: lint")
      fi
      if ! uses_biome "$target"; then
        if ! run_step "$target: format" "npx prettier --write ."; then
          failed+=("$target: format")
        fi
      fi
    fi
  fi
done

# --- Summary ---

echo ""
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "❌ Failed: ${failed[*]}"
  exit 1
fi

echo "✅ All lint checks passed!"
