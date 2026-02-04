#!/bin/bash
set -euo pipefail

function check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker not installed" >&2
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "Error: Docker daemon not running" >&2
        exit 1
    fi
}

if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "Error: Not inside a git repository" >&2
    exit 1
fi
MONOREPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$MONOREPO_ROOT"
PROJECT_NAME="$(basename "$MONOREPO_ROOT")"

# Ensure Docker CLI is in PATH (Docker Desktop on macOS)
[[ -d "/Applications/Docker.app/Contents/Resources/bin" ]] && \
    export PATH="$PATH:/Applications/Docker.app/Contents/Resources/bin"

check_docker

# docker compose wrapper: use worktree/dev compose file from tmp dir when present
dc() {
  local tmp_base="${DEV_STACKS_DIR:-$HOME/work/tmp/dev-stacks}/$PROJECT_NAME"
  local wt_compose="$tmp_base/docker-compose.worktree.yml"
  local main_compose="$tmp_base/docker-compose.dev.yml"
  if [[ -f "$wt_compose" ]]; then
    COMPOSE_PROJECT_NAME="$PROJECT_NAME" docker compose \
      -f docker-compose.yml -f "$wt_compose" "$@"
  elif [[ -f "$main_compose" ]]; then
    COMPOSE_PROJECT_NAME="$PROJECT_NAME" docker compose \
      -f docker-compose.yml -f "$main_compose" "$@"
  else
    COMPOSE_PROJECT_NAME="$PROJECT_NAME" docker compose "$@"
  fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <service> [service2...] [flags]

Services: frontend, registries, studies, admin, codelist

Flags:
  --deps,    -d   Force host npm install
  --migrate, -m   Force migrations after rebuild
  --full,    -f   Force all steps (deps + build + migrate + supergraph)

By default, the script auto-detects what changed (git diff) and only
runs the steps that are needed. Flags override auto-detection.

Examples:
  $(basename "$0") frontend                  # Auto-detect changes
  $(basename "$0") registries --full         # Force all steps
  $(basename "$0") frontend registries       # Multiple services
  $(basename "$0") registries --deps --migrate
EOF
  exit 1
}

if [[ $# -eq 0 ]]; then
  usage
fi

# --- Service configuration ---

service_dir() {
  case "$1" in
    frontend)   echo "apps/main-frontend" ;;
    registries) echo "services/registries" ;;
    studies)    echo "services/studies" ;;
    admin)      echo "services/admin" ;;
    codelist)   echo "services/codelist" ;;
    *) echo "Unknown service: $1" >&2; exit 1 ;;
  esac
}

docker_name() {
  case "$1" in
    frontend) echo "main-frontend" ;;
    *)        echo "$1" ;;
  esac
}

has_migrations() {
  case "$1" in
    registries|studies|codelist) return 0 ;;
    *) return 1 ;;
  esac
}

has_supergraph() {
  case "$1" in
    registries|studies|admin) return 0 ;;
    *) return 1 ;;
  esac
}

# --- Parse arguments ---

services=()
force_deps=false
force_migrate=false
force_full=false

for arg in "$@"; do
  case "$arg" in
    --deps|-d)    force_deps=true ;;
    --migrate|-m) force_migrate=true ;;
    --full|-f)    force_full=true ;;
    -*)           echo "Unknown flag: $arg" >&2; usage ;;
    *)            services+=("$arg") ;;
  esac
done

if [[ ${#services[@]} -eq 0 ]]; then
  echo "Error: no services specified" >&2
  usage
fi

# Validate service names
for service in "${services[@]}"; do
  service_dir "$service" > /dev/null
done

# --- Auto-detect what each service needs ---

# Use regular arrays instead of associative arrays (bash 3.x compatibility)
services_needing_deps=()
services_needing_migrate=()
global_needs_supergraph=false
docker_services_to_build=()

for service in "${services[@]}"; do
  dir=$(service_dir "$service")
  docker=$(docker_name "$service")

  needs_deps=false
  needs_migrate=false
  needs_supergraph=false

  if $force_full; then
    needs_deps=true
    needs_migrate=true
    needs_supergraph=true
  else
    # Check both staged and unstaged changes
    changed_files=$(git diff --name-only HEAD -- "$dir" 2>/dev/null || true)
    # Also include untracked files within the service directory
    untracked_files=$(git ls-files --others --exclude-standard -- "$dir" 2>/dev/null || true)
    all_changes="${changed_files}"$'\n'"${untracked_files}"

    if echo "$all_changes" | grep -qE 'package(-lock)?\.json'; then
      needs_deps=true
    fi

    if echo "$all_changes" | grep -qE 'prisma/'; then
      needs_migrate=true
    fi

    if echo "$all_changes" | grep -qE '\.graphql$'; then
      needs_supergraph=true
    fi

    # Apply flag overrides
    if $force_deps; then needs_deps=true; fi
    if $force_migrate; then needs_migrate=true; fi
  fi

  # Track which services need each step
  if $needs_deps; then
    services_needing_deps+=("$service")
  fi
  if $needs_migrate && has_migrations "$service"; then
    services_needing_migrate+=("$service")
  fi
  docker_services_to_build+=("$docker")

  if $needs_supergraph && has_supergraph "$service"; then
    global_needs_supergraph=true
  fi

  # --- Print summary ---
  echo ""
  echo "=== $service ==="

  detected=()
  steps=("docker rebuild")
  skipping=()

  if $needs_deps; then
    detected+=("dependency changes")
    steps=("npm install" "${steps[@]}")
  else
    skipping+=("npm install")
  fi

  if $needs_migrate && has_migrations "$service"; then
    detected+=("prisma schema changes")
    steps+=("run migrations")
  elif has_migrations "$service"; then
    skipping+=("migrations")
  fi

  if $needs_supergraph && has_supergraph "$service"; then
    detected+=("graphql schema changes")
    steps+=("supergraph regen")
  elif has_supergraph "$service"; then
    skipping+=("supergraph")
  fi

  if $force_full; then
    echo "  Mode: --full (all steps forced)"
  elif $force_deps || $force_migrate; then
    echo "  Mode: auto-detect + flag overrides"
  fi

  if [[ ${#detected[@]} -gt 0 ]]; then
    echo "  Detected: $(IFS=', '; echo "${detected[*]}")"
  fi
  echo "  Steps: $(IFS=', '; echo "${steps[*]}")"
  if [[ ${#skipping[@]} -gt 0 ]]; then
    echo "  Skipping: $(IFS=', '; echo "${skipping[*]}")"
  fi
done

# --- Execute steps ---

# Step 1: Run npm install in parallel for services that need it
npm_pids=()
if [[ -n "${services_needing_deps[*]:-}" ]]; then
  for service in "${services_needing_deps[@]}"; do
    dir=$(service_dir "$service")
    echo ""
    echo "-> Starting npm install in $dir (background)..."
    (cd "$MONOREPO_ROOT/$dir" && npm install) &
    npm_pids+=($!)
  done

  echo ""
  echo "-> Waiting for npm installs to complete..."
  for pid in "${npm_pids[@]}"; do
    wait "$pid"
  done
  echo "-> All npm installs completed."
fi

# Step 2: Build all Docker images in parallel, then start them
echo ""
echo "-> Building Docker images in parallel: ${docker_services_to_build[*]}..."
dc build --parallel "${docker_services_to_build[@]}"

echo ""
echo "-> Starting services: ${docker_services_to_build[*]}..."
dc up -d --wait "${docker_services_to_build[@]}"

# Step 3: Run migrations sequentially for services that need them
if [[ -n "${services_needing_migrate[*]:-}" ]]; then
  for service in "${services_needing_migrate[@]}"; do
    docker=$(docker_name "$service")
    echo ""
    echo "-> Running migrations for $service..."
    dc exec "$docker" sh -c \
      'POSTGRES_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DATABASE}" npm run migrate'
  done
fi

# Run supergraph regen once if any service needed it
if $global_needs_supergraph; then
  echo ""
  echo "=== Regenerating supergraph ==="
  (cd "$MONOREPO_ROOT/services/apollo-router" && ./compose-supergraph.sh)
fi

echo ""
echo "Done."
