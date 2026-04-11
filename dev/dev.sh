#!/bin/bash
set -euo pipefail

### dev.sh — Unified dev stack manager
### Auto-detects main vs worktree, wraps docker compose with correct override files.
###
### Usage:
###   dev up [--build] [services...]     Start stack (full init flow)
###   dev down                           Stop and remove containers
###   dev nuke                           Full teardown (volumes, images, slot)
###   dev status                         Show all running stacks
###   dev start [services...]            Start stopped containers
###   dev <any docker compose command>   Passthrough to docker compose
###
### Examples:
###   dev up                             Start default services
###   dev up --build registries          Rebuild one service
###   dev restart registries             Restart a service
###   dev logs -f registries             Tail logs
###   dev exec registries sh             Shell into container
###   dev ps                             List containers

ADMIN_MOCK_NET="admin-mock-net"
DEV_SLOT_LABEL="com.ledidi.dev-slot"
FRONTEND_BASE_PORT=3003

# --- Shared utility functions ---

check_docker() {
    if ! command -v docker &>/dev/null; then
        echo "Error: Docker not installed" >&2
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo "Error: Docker daemon not running" >&2
        exit 1
    fi
}

check_admin_mock() {
    if ! docker inspect admin-mock &>/dev/null 2>&1; then
        echo "Error: admin-mock container is not running." >&2
        echo "" >&2
        echo "Build and start it first:" >&2
        echo "  cd ~/.config/dev/admin-mock" >&2
        echo "  docker build -t admin-mock ." >&2
        echo "  docker network create $ADMIN_MOCK_NET 2>/dev/null || true" >&2
        echo "  docker run -d --name admin-mock --restart unless-stopped \\" >&2
        echo "    --network $ADMIN_MOCK_NET --hostname admin-service.internal admin-mock" >&2
        exit 1
    fi

    local state
    state=$(docker inspect -f '{{.State.Running}}' admin-mock 2>/dev/null || echo "false")
    if [ "$state" != "true" ]; then
        echo "admin-mock container exists but is not running. Starting it..."
        docker start admin-mock
    fi

    docker network create "$ADMIN_MOCK_NET" 2>/dev/null || true
    docker network connect "$ADMIN_MOCK_NET" admin-mock 2>/dev/null || true
}

prerequisites_check() {
    check_docker
}

# Remove stopped containers whose network references may be stale.
# Docker Desktop (or a Docker daemon restart) can recreate networks with new
# IDs while stopped containers still reference the old ones, causing
# "network <id> not found" on start.
cleanup_stale_containers() {
    local stale
    stale=$(docker ps -aq \
        --filter "label=com.docker.compose.project=${project_name}" \
        --filter "status=exited" 2>/dev/null)
    if [ -n "$stale" ]; then
        echo "Removing stale containers..."
        docker rm -f $stale 2>/dev/null || true
    fi
}

wait_for_migrations() {
    local service=$1
    local db_name=$service
    local max_attempts=30
    local attempt=0
    echo "Waiting for $service migrations to complete..."
    while [ $attempt -lt $max_attempts ]; do
        if dc exec -T postgres psql -U postgres -d "$db_name" -c "SELECT 1 FROM _prisma_migrations LIMIT 1" &>/dev/null; then
            echo "$service migrations complete."
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    echo "Warning: Timed out waiting for $service migrations."
    return 1
}

run_seed() {
    wait_for_migrations registries

    # Note: prisma generate is NOT run here — the container's own CMD (npm run dev)
    # already runs generate before migrate. Running it again while nodemon watchers
    # are active triggers a restart loop (writes .ts files → dev:watch detects → restarts).

    echo "Seeding ICD-10 codes..."
    dc exec -T registries sh -c 'POSTGRES_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/registries" npm run seed-icd10'

    echo "Seeding ATC codes..."
    dc exec -T registries sh -c 'POSTGRES_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/registries" npm run seed-atc'

    echo
    echo "Data seeded successfully."
    echo
}

available_services() {
    local all_services="$1"
    local result=""
    for svc in $all_services; do
        if grep -qE "^\s+${svc}:" "$repo_root/docker-compose.yml" 2>/dev/null; then
            result="$result $svc"
        fi
    done
    echo "$result"
}

# --- Mode detection ---

if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "Error: Not inside a git repository" >&2
    exit 1
fi
repo_root="$(git rev-parse --show-toplevel)"
project_name="$(basename "$repo_root")"

if [ -f "$repo_root/.git" ]; then
    mode="worktree"   # .git is a file in worktrees, containing gitdir pointer
else
    mode="main"       # .git is a directory in main checkouts
fi

tmp_dir="${DEV_STACKS_DIR:-$HOME/work/.dev-stacks}/$project_name"

# --- Slot management ---

slot_file="$tmp_dir/worktree-slot"

is_slot_in_use() {
    local s=$1
    local containers
    containers=$(docker ps -aq --filter "label=${DEV_SLOT_LABEL}=${s}" 2>/dev/null)
    [ -n "$containers" ]
}

next_available_slot() {
    local lockdir="/tmp/dev-slot.lock"
    local stale_seconds=30

    if [ -d "$lockdir" ]; then
        local lock_age
        if [[ "$OSTYPE" == darwin* ]]; then
            lock_age=$(( $(date +%s) - $(stat -f %m "$lockdir" 2>/dev/null || echo 0) ))
        else
            lock_age=$(( $(date +%s) - $(stat -c %Y "$lockdir" 2>/dev/null || echo 0) ))
        fi
        if [ "$lock_age" -gt "$stale_seconds" ]; then
            rmdir "$lockdir" 2>/dev/null || true
        fi
    fi

    if ! mkdir "$lockdir" 2>/dev/null; then
        echo "Error: Another instance is allocating a slot. If this persists, run: rmdir $lockdir" >&2
        exit 1
    fi

    trap 'rmdir "$lockdir" 2>/dev/null' EXIT

    for s in $(seq 1 9); do
        if ! is_slot_in_use "$s"; then
            rmdir "$lockdir" 2>/dev/null
            trap - EXIT
            echo "$s"
            return
        fi
    done

    rmdir "$lockdir" 2>/dev/null
    trap - EXIT
    echo "Error: All slots (1-9) are in use." >&2
    exit 1
}

save_slot() {
    mkdir -p "$tmp_dir"
    echo "$1" > "$slot_file"
}

read_saved_slot() {
    if [ -f "$slot_file" ]; then
        cat "$slot_file"
    else
        echo ""
    fi
}

clear_saved_slot() {
    rm -f "$slot_file"
}

# resolve_slot returns 0 for main mode, saved/auto-assigned slot for worktree mode
resolve_slot() {
    if [ "$mode" = "main" ]; then
        echo "0"
        return
    fi

    local saved
    saved=$(read_saved_slot)
    if [ -n "$saved" ]; then
        if is_slot_in_use "$saved"; then
            echo "$saved"
            return
        else
            # Stale slot file — clear it and fall through to auto-assign
            clear_saved_slot
        fi
    fi

    # Auto-assign for "up" command, error for others
    if [ "$subcommand" = "up" ]; then
        next_available_slot
    else
        echo "Error: No slot assigned yet. Run 'dev up' first." >&2
        exit 1
    fi
}

# --- Override generation ---

generate_main_override() {
    mkdir -p "$tmp_dir"
    local override_file="$tmp_dir/docker-compose.stack.yml"

    cat > "$override_file" <<YAML
# Auto-generated by dev.sh (main mode)
# Do not edit — regenerated on each run.

services:
  registries-frontend:
    labels:
      ${DEV_SLOT_LABEL}: "0"
  admin:
    profiles: ["disabled"]
  mysql:
    profiles: ["disabled"]
  registries:
    networks:
      - default
      - $ADMIN_MOCK_NET

networks:
  $ADMIN_MOCK_NET:
    external: true
YAML
}

generate_worktree_override() {
    local s=$1
    local offset=$(( s * 100 ))
    mkdir -p "$tmp_dir"
    local override_file="$tmp_dir/docker-compose.stack.yml"

    cat > "$override_file" <<YAML
# Auto-generated by dev.sh (worktree slot $s, offset $offset)
# Do not edit — regenerated on each run.

services:
  registries-frontend:
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
    environment:
      - VITE_APP_URL=http://localhost:$(( FRONTEND_BASE_PORT + offset ))
      - VITE_GRAPHQL_URI=http://localhost:$(( 4006 + offset ))/graphql
      - VITE_GRAPHQL_PROM_URI=http://localhost:$(( 4006 + offset ))/graphql-prom
      - VITE_SURVEY_URL=http://localhost:$(( FRONTEND_BASE_PORT + offset ))/surveys
      - VITE_AGENT_SERVICE_URL=http://localhost:$(( 4007 + offset ))
    volumes: !override
      - $repo_root/apps/registries-frontend/src:/apps/registries-frontend/src:cached
      - $repo_root/services/studies/api:/services/studies/api:cached
      - $repo_root/services/admin/api:/services/admin/api:cached
    ports: !override
      - "$(( FRONTEND_BASE_PORT + offset )):$FRONTEND_BASE_PORT"

  admin:
    profiles: ["disabled"]
  mysql:
    profiles: ["disabled"]

  postgres:
    ports: !override
      - "$(( 5432 + offset )):5432"
    volumes: !override
      - database_data_wt_${s}:/var/lib/postgresql/data:rw

  codelist:
    volumes: !override
      - $repo_root/services/codelist/src:/app/services/codelist/src
      - $repo_root/services/codelist/api:/app/services/codelist/api
      - $repo_root/services/codelist/prisma:/app/services/codelist/prisma
      - ~/.aws:/root/.aws:ro
    ports: !override
      - "$(( 4005 + offset )):4000"
      - "$(( 50005 + offset )):50051"

  registries:
    networks:
      - default
      - admin-bridge
    environment:
      - ALLOWED_ORIGINS=http://localhost:$(( FRONTEND_BASE_PORT + offset )),http://localhost:3010
    volumes: !override
      - $repo_root/services/registries/src:/app/services/registries/src
      - $repo_root/services/registries/api:/app/services/registries/api
      - $repo_root/services/registries/prisma:/app/services/registries/prisma
      - $repo_root/services/admin/api:/app/services/admin/api
      - $repo_root/services/codelist/api:/app/services/codelist/api
      - ~/.aws:/root/.aws:ro
    ports: !override
      - "$(( 4006 + offset )):4000"
      - "$(( 50006 + offset )):50051"
      - "$(( 4002 + offset )):4002"
YAML

    # Conditionally add services that may not exist in all branches
    if grep -qE '^\s+agent:' "$repo_root/docker-compose.yml" 2>/dev/null; then
        cat >> "$override_file" <<AGENT_YAML

  agent:
    ports: !override
      - "$(( 4007 + offset )):4000"
AGENT_YAML
    fi

    # Append networks and volumes sections last
    cat >> "$override_file" <<NETWORKS_YAML

networks:
  default:
    name: default-network-wt-${s}
    driver: bridge
  admin-bridge:
    name: admin-bridge-wt-${s}
    external: true

volumes:
  database_data_wt_${s}:
NETWORKS_YAML
}

generate_override() {
    local slot=$1
    if [ "$mode" = "main" ]; then
        generate_main_override
    else
        generate_worktree_override "$slot"
    fi
}

# --- Docker compose wrapper ---

dc() {
    COMPOSE_PROJECT_NAME="$project_name" docker compose \
        -f "$repo_root/docker-compose.yml" \
        -f "$tmp_dir/docker-compose.stack.yml" \
        "$@"
}

# --- Context file management ---

context_dir="$HOME/.config/dev/context/ledidi-monorepo"
claude_local_md="$repo_root/CLAUDE.local.md"
agents_md="$repo_root/AGENTS.md"

apply_context_replacements() {
    local file=$1
    shift

    [ -f "$file" ] || return

    for pair in "$@"; do
        local tag="${pair%%:*}"
        local value="${pair##*:}"
        if [[ "$OSTYPE" == darwin* ]]; then
            sed -i '' "s|${tag}|${value}|g" "$file"
        else
            sed -i "s|${tag}|${value}|g" "$file"
        fi
    done
}

sync_context_files() {
    local s=$1
    local offset=$(( s * 100 ))
    local claude_template="$context_dir/CLAUDE.local.md"
    local agents_template="$context_dir/AGENTS.md"

    if [ ! -f "$claude_template" ]; then
        echo "Warning: CLAUDE.local.md template not found at $claude_template" >&2
    else
        cp "$claude_template" "$claude_local_md"
    fi

    if [ ! -f "$agents_template" ]; then
        echo "Warning: AGENTS.md template not found at $agents_template" >&2
    else
        cp "$agents_template" "$agents_md"
    fi

    local replacements=(
        "{{FRONTEND_PORT}}:$(( FRONTEND_BASE_PORT + offset ))"
        "{{POSTGRES_PORT}}:$(( 5432 + offset ))"
        "{{CODELIST_PORT}}:$(( 4005 + offset ))"
        "{{CODELIST_GRPC_PORT}}:$(( 50005 + offset ))"
        "{{REGISTRIES_PORT}}:$(( 4006 + offset ))"
        "{{REGISTRIES_GRPC_PORT}}:$(( 50006 + offset ))"
        "{{AGENT_PORT}}:$(( 4007 + offset ))"
    )

    apply_context_replacements "$claude_local_md" "${replacements[@]}"
    apply_context_replacements "$agents_md" "${replacements[@]}"
}

remove_context_files() {
    rm -f "$claude_local_md"
    rm -f "$agents_md"
}

write_env_files() {
    local s=$1
    local offset=$(( s * 100 ))
    local pg_port=$(( 5432 + offset ))

    cat > "$repo_root/services/registries/.env.test.local" <<EOF
POSTGRES_URL=postgresql://postgres:postgres@localhost:${pg_port}/registries-test
EOF
}

remove_env_files() {
    rm -f "$repo_root/services/registries/.env.test.local"
}

# --- Status ---

show_status() {
    echo "Running dev stacks:"
    echo

    local found=0

    # Check main stack (slot 0)
    local main_container
    main_container=$(docker ps -q --filter "label=${DEV_SLOT_LABEL}=0" 2>/dev/null | head -1)
    if [ -n "$main_container" ]; then
        found=1
        local project
        project=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$main_container" 2>/dev/null)
        local count
        count=$(docker ps -q --filter "label=com.docker.compose.project=${project}" 2>/dev/null | wc -l | tr -d ' ')
        echo "  Main — $project"
        echo "    Frontend:   http://localhost:$FRONTEND_BASE_PORT/en"
        echo "    Postgres:   localhost:5432"
        echo "    Containers: $count"
        echo
    fi

    # Check worktree stacks (slots 1-9)
    for s in $(seq 1 9); do
        local container
        container=$(docker ps -q --filter "label=${DEV_SLOT_LABEL}=${s}" 2>/dev/null | head -1)
        if [ -n "$container" ]; then
            found=1
            local offset=$(( s * 100 ))
            local project
            project=$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$container" 2>/dev/null)
            local count
            count=$(docker ps -q --filter "label=com.docker.compose.project=${project}" 2>/dev/null | wc -l | tr -d ' ')
            echo "  Slot $s — $project"
            echo "    Frontend:   http://localhost:$(( FRONTEND_BASE_PORT + offset ))/en"
            echo "    Agent:      http://localhost:$(( 4007 + offset ))"
            echo "    Postgres:   localhost:$(( 5432 + offset ))"
            echo "    Containers: $count"
            echo
        fi
    done

    if [ "$found" -eq 0 ]; then
        echo "  No dev stacks running."
    fi
}

# --- Command routing ---

if [ "$#" -lt 1 ]; then
    echo "Usage: dev <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  up [--build] [services...]  Start stack (full init flow)"
    echo "  down                        Stop and remove containers"
    echo "  nuke                        Full teardown (volumes, images, slot)"
    echo "  status                      Show all running stacks"
    echo "  start [services...]         Start stopped containers"
    echo "  <any>                       Passthrough to docker compose"
    exit 1
fi

subcommand="$1"
shift

# Status doesn't need slot resolution or override generation
if [ "$subcommand" = "status" ]; then
    show_status
    exit 0
fi

prerequisites_check

resolved_slot=$(resolve_slot)
offset=$(( resolved_slot * 100 ))

if [ "$mode" = "worktree" ]; then
    echo "Mode: worktree (slot $resolved_slot, offset +$offset)"
else
    echo "Mode: main (default ports)"
fi
echo "Project: $project_name"
if [ "$offset" -gt 0 ]; then
    echo "Frontend: http://localhost:$(( FRONTEND_BASE_PORT + offset ))/en"
fi
echo

default_services=$(available_services "registries-frontend postgres codelist registries agent")

case "$subcommand" in
    up)
        check_admin_mock
        [ "$mode" = "worktree" ] && save_slot "$resolved_slot"

        # Clean up stopped containers before network setup — their stale network
        # references would prevent network removal and cause start failures.
        cleanup_stale_containers

        # Create per-slot bridge network so compose services can reach admin-mock
        if [ "$mode" = "worktree" ]; then
            # Remove stale default network from a previous project that used this slot
            docker network rm "default-network-wt-${resolved_slot}" 2>/dev/null || true
            docker network create "admin-bridge-wt-${resolved_slot}" 2>/dev/null || true
            docker network connect "admin-bridge-wt-${resolved_slot}" admin-mock 2>/dev/null || true
        fi

        generate_override "$resolved_slot"

        if [ "$#" -gt 0 ]; then
            dc up "$@" -d --wait
        else
            dc up -d --wait $default_services
        fi
        run_seed
        sync_context_files "$resolved_slot"
        write_env_files "$resolved_slot"

        echo "Stack is running at http://localhost:$(( FRONTEND_BASE_PORT + offset ))/en/registries"
        ;;

    down)
        generate_override "$resolved_slot"
        dc down "$@"
        if [ "$mode" = "worktree" ]; then
            docker network disconnect "default-network-wt-${resolved_slot}" admin-mock 2>/dev/null || true
            docker network rm "default-network-wt-${resolved_slot}" 2>/dev/null || true
        fi
        remove_context_files
        remove_env_files
        ;;

    nuke)
        echo "This will remove all containers, volumes, and images for this stack."
        # Only prompt if stdin is a terminal (skip in non-interactive/piped contexts)
        if [ -t 0 ]; then
            read -r -p "Are you sure? (y/N): " confirm
            echo
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Nuke cancelled."
                exit 0
            fi
        fi
        generate_override "$resolved_slot"
        dc down -v --rmi local --remove-orphans
        if [ "$mode" = "worktree" ]; then
            docker network disconnect "admin-bridge-wt-${resolved_slot}" admin-mock 2>/dev/null || true
            docker network disconnect "default-network-wt-${resolved_slot}" admin-mock 2>/dev/null || true
            docker network rm "admin-bridge-wt-${resolved_slot}" 2>/dev/null || true
            docker network rm "default-network-wt-${resolved_slot}" 2>/dev/null || true
            clear_saved_slot
        fi
        remove_context_files
        remove_env_files
        rm -rf "$tmp_dir"
        echo
        echo "Nuke complete."
        ;;

    start)
        check_admin_mock
        cleanup_stale_containers

        if [ "$mode" = "worktree" ]; then
            docker network rm "default-network-wt-${resolved_slot}" 2>/dev/null || true
            docker network create "admin-bridge-wt-${resolved_slot}" 2>/dev/null || true
            docker network connect "admin-bridge-wt-${resolved_slot}" admin-mock 2>/dev/null || true
        fi

        generate_override "$resolved_slot"
        if [ "$#" -gt 0 ]; then
            dc up -d "$@"
        else
            dc up -d $default_services
        fi
        ;;

    *)
        # Pure passthrough to docker compose
        generate_override "$resolved_slot"
        dc "$subcommand" "$@"
        ;;
esac
