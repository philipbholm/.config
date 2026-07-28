#!/bin/bash
set -euo pipefail

. "$HOME/.config/dev/lib/workspace.sh"

# Per-developer overrides for docker-compose env interpolation (e.g. each
# dev's reserved ngrok subdomain for the patient-bff Helsenorge tunnel).
# `set -a` exports every var assigned in the file so `docker compose` sees
# them. The file is gitignore-irrelevant since it lives outside the repo.
if [ -f "$HOME/.config/dev/.env.local" ]; then
    set -a
    . "$HOME/.config/dev/.env.local"
    set +a
fi

### dev.sh — Unified dev stack manager
### Auto-detects main vs worktree, wraps docker compose with correct override files.
###
### Usage:
###   dev up [--slot N] [--include-patient] [--build] [services...]  Start stack (full init flow)
###   dev down                           Stop and remove containers
###   dev nuke [--yes]                   Full teardown (volumes, images, slot)
###   dev status                         Show all running stacks
###   dev start [services...]            Start stopped containers
###   dev <any docker compose command>   Passthrough to docker compose
###
### Flags:
###   --slot N           Pin to slot 1-9 (worktrees only; default: lowest free)
###   --include-patient  Include patient-bff and patient-frontend if present in the
###                      worktree (pins port 4010; off by default so only one stack
###                      at a time grabs it)
###   --yes              Skip nuke's confirmation prompt. Required when stdin is not
###                      a terminal (scripts, agents), where there is nothing to
###                      prompt on.
###
### Examples:
###   dev up                             Start default services (no patient stack)
###   dev up --include-patient           Also start patient-bff/patient-frontend
###   dev up --build registries          Rebuild one service
###   dev restart registries             Restart a service
###   dev logs -f registries             Tail logs
###   dev exec registries sh             Shell into container
###   dev ps                             List containers

ADMIN_MOCK_NET="admin-mock-net"
SYNC_CONTEXT="$HOME/.config/dev/sync-context.sh"

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

worktree_has_patient_bff() {
    [ "${include_patient:-false}" = "true" ] || return 1
    [ -f "$repo_root/services/patient-bff/Dockerfile.dev" ]
}

worktree_has_patient_frontend() {
    [ "${include_patient:-false}" = "true" ] || return 1
    [ -f "$repo_root/apps/patient-frontend/Dockerfile.dev" ]
}

available_services() {
    local defined_services=""
    local result=()
    local svc

    defined_services=$(docker compose -f "$repo_root/docker-compose.yml" config --services 2>/dev/null || true)

    for svc in "$@"; do
        if [ -n "$defined_services" ]; then
            if printf '%s\n' "$defined_services" | grep -qx "$svc"; then
                result+=("$svc")
            fi
        elif grep -qE "^\s+${svc}:" "$repo_root/docker-compose.yml" 2>/dev/null; then
            result+=("$svc")
        fi
    done

    # An empty array must not be expanded under `set -u` on bash 3.2.
    if [ "${#result[@]}" -gt 0 ]; then
        printf '%s\n' "${result[@]}"
    fi
}

collect_compose_services() {
    local expect_value=false
    local stop_parsing_options=false
    local arg

    for arg in "$@"; do
        if [ "$expect_value" = true ]; then
            expect_value=false
            continue
        fi

        if [ "$stop_parsing_options" = true ]; then
            printf '%s\n' "$arg"
            continue
        fi

        case "$arg" in
            --)
                stop_parsing_options=true
                ;;
            --attach|--exit-code-from|--no-attach|--pull|--scale|--timeout|--wait-timeout|-t)
                expect_value=true
                ;;
            --abort-on-container-exit|--abort-on-container-failure|--always-recreate-deps|--build|--detach|--force-recreate|--menu|--no-build|--no-color|--no-deps|--no-log-prefix|--no-recreate|--no-start|--quiet-build|--quiet-pull|--remove-orphans|--renew-anon-volumes|--timestamps|--wait|-V|-d)
                ;;
            -*)
                ;;
            *)
                printf '%s\n' "$arg"
                ;;
        esac
    done
}

service_list_contains() {
    local target=$1
    shift
    local service

    for service in "$@"; do
        if [ "$service" = "$target" ]; then
            return 0
        fi
    done

    return 1
}

# Reached when the compose file defines none of the services this stack expects,
# e.g. `dev up` in some other git repo. Name that instead of letting an empty
# service list reach docker compose.
require_services() {
    [ "${#requested_services[@]}" -gt 0 ] && return 0

    echo "Error: $repo_root/docker-compose.yml defines none of this stack's services" >&2
    echo "(registries-frontend, postgres, codelist, registries, agent)." >&2
    echo "Pass the services you want explicitly: dev $subcommand <service>..." >&2
    exit 1
}

# --- Mode detection ---

if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "Error: Not inside a git repository" >&2
    exit 1
fi
repo_root="$(git rev-parse --show-toplevel)"
base_project_name="$(dev_workspace_id_for_repo "$repo_root")"
project_name="$base_project_name"  # Reassigned to wt{slot}-${base} after slot resolution.

if [ -f "$repo_root/.git" ]; then
    mode="worktree"   # .git is a file in worktrees, containing gitdir pointer
else
    mode="main"       # .git is a directory in main checkouts
fi

# Holds the generated override and the slot file, and `dev nuke` rm -rf's it, so
# refuse to run at all if it ever resolves to something we must not delete.
tmp_dir="$(dev_stack_dir_for_repo "$repo_root")"
case "$tmp_dir" in
    ''|'/'|"$HOME"|"$HOME/") echo "Error: refusing to use '$tmp_dir' as this stack's state dir." >&2; exit 1 ;;
esac

# --- Slot management ---

slot_file="$(dev_slot_file_for_repo "$repo_root")"

is_slot_in_use() {
    local s=$1
    local containers
    containers=$(docker ps -aq --filter "label=${DEV_SLOT_LABEL}=${s}" 2>/dev/null)
    if [ -n "$containers" ]; then
        return 0
    fi

    # Docker has nothing on this slot — any slot file claiming it is stale
    # (containers were removed manually instead of via `dev nuke`).
    dev_clear_stale_slot_files "$repo_root" "$s"
    return 1
}

slot_from_existing_stack() {
    local container

    container=$(docker ps -aq \
        --filter "label=${DEV_WORKSPACE_LABEL}=${base_project_name}" \
        --filter "label=${DEV_SLOT_LABEL}" 2>/dev/null | head -1)
    if [ -z "$container" ]; then
        return 1
    fi

    docker inspect --format "{{index .Config.Labels \"$DEV_SLOT_LABEL\"}}" "$container" 2>/dev/null
}

# Serializes slot allocation. is_slot_in_use answers from the dev-slot label on
# running containers, so a claim is only visible to a competing run once the
# containers exist — the lock therefore has to be held from the free-slot scan
# all the way through `dc create` (see the up branch), not just until a number
# has been picked. That stretch can take minutes on a cold create, so a lock is
# stale when the pid that took it is gone rather than after a fixed age, and
# competing runs wait instead of failing.
SLOT_LOCKDIR="/tmp/dev-slot.lock"
slot_lock_held="false"

acquire_slot_lock() {
    local wait_limit=600
    local waited=0
    local announced=false
    local holder

    while true; do
        if mkdir "$SLOT_LOCKDIR" 2>/dev/null; then
            echo "$$" > "$SLOT_LOCKDIR/owner"
            slot_lock_held="true"
            trap release_slot_lock EXIT
            return 0
        fi

        holder=$(cat "$SLOT_LOCKDIR/owner" 2>/dev/null || true)
        if [ -z "$holder" ] || ! kill -0 "$holder" 2>/dev/null; then
            # Whoever took it is gone (crash, kill -9).
            rm -f "$SLOT_LOCKDIR/owner"
            if rmdir "$SLOT_LOCKDIR" 2>/dev/null; then
                continue
            fi
            echo "Error: cannot clear the abandoned slot lock at $SLOT_LOCKDIR." >&2
            exit 1
        fi

        if [ "$announced" = false ]; then
            echo "Waiting for another dev run (pid $holder) to claim its slot..."
            announced=true
        fi
        if [ "$waited" -ge "$wait_limit" ]; then
            echo "Error: timed out waiting for the slot lock held by pid $holder." >&2
            echo "If that process is gone, run: rm -rf $SLOT_LOCKDIR" >&2
            exit 1
        fi
        sleep 2
        waited=$(( waited + 2 ))
    done
}

release_slot_lock() {
    [ "$slot_lock_held" = "true" ] || return 0
    slot_lock_held="false"
    rm -f "$SLOT_LOCKDIR/owner"
    rmdir "$SLOT_LOCKDIR" 2>/dev/null || true
}

# Only call while holding the slot lock — the scan is meaningless without it.
next_available_slot() {
    local s

    for s in $(seq 1 9); do
        if ! is_slot_in_use "$s"; then
            echo "$s"
            return
        fi
    done

    echo "Error: All slots (1-9) are in use." >&2
    exit 1
}

save_slot() {
    mkdir -p "$tmp_dir"
    echo "$1" > "$slot_file"
}

read_saved_slot() {
    if [ -f "$slot_file" ]; then
        tr -d '[:space:]' < "$slot_file"
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

    # Honor explicit --slot override
    if [ -n "$slot_override" ]; then
        if is_slot_in_use "$slot_override"; then
            echo "Error: Slot $slot_override is already in use by another stack." >&2
            exit 1
        fi
        echo "$slot_override"
        return
    fi

    local detected
    local saved

    detected=$(slot_from_existing_stack || true)
    if [ -n "$detected" ]; then
        if [ "$detected" != "$(read_saved_slot)" ]; then
            save_slot "$detected"
        fi
        echo "$detected"
        return
    fi

    # No containers exist for this workspace. For `up`, re-allocate the lowest free
    # slot rather than honoring the saved slot — the saved value is stale state, not
    # a reservation, and shouldn't keep a lower-numbered free slot from being claimed.
    if [ "$subcommand" = "up" ]; then
        next_available_slot
        return
    fi

    saved=$(read_saved_slot)
    if [ -n "$saved" ]; then
        if ! is_slot_in_use "$saved"; then
            echo "$saved"
            return
        else
            echo "Error: Saved slot $saved is already in use by another stack." >&2
            echo "Use 'dev up --slot N' to specify a different slot." >&2
            exit 1
        fi
    fi

    echo "Error: No slot assigned yet. Run 'dev up' first." >&2
    exit 1
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
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
  admin:
    profiles: ["disabled"]
  mysql:
    profiles: ["disabled"]
  registries:
    environment:
      # Raise PROM endpoint rate limit (default 100/min) to the schema cap so
      # local seeders aren't throttled. See services/registries/src/env.ts.
      - PROM_RATE_LIMIT_MAX=10000
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

    # patient-bff public URL: the HTTPS ngrok tunnel from ~/.config/dev/.env.local
    # when set, else the localhost default. Used by BOTH the registries service
    # (which stamps it into the Helsenorge oppgave's Task.instantiatesUri —
    # eksternapi rejects non-HTTPS with FHIR code 2174) and the patient-bff
    # service below. Baked in as a literal so every recreate path (dev.sh,
    # tunnel.sh, manual `docker compose up registries`) picks it up without
    # relying on the var being exported into the compose process at up-time.
    local default_bff_url="http://localhost:4010"
    local bff_public_url="${NGROK_PATIENT_BFF_URL:-$default_bff_url}"

    cat > "$override_file" <<YAML
# Auto-generated by dev.sh (worktree slot $s, offset $offset)
# Do not edit — regenerated on each run.

services:
  registries-frontend:
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
    environment:
      - VITE_APP_URL=http://localhost:$(( DEV_FRONTEND_BASE_PORT + offset ))
      - VITE_GRAPHQL_URI=http://localhost:$(( 4006 + offset ))/graphql
      - VITE_GRAPHQL_PROM_URI=http://localhost:$(( 4006 + offset ))/graphql-prom
      - VITE_REGISTRIES_API_URL=http://localhost:$(( 4006 + offset ))
      - VITE_SURVEY_URL=http://localhost:$(( DEV_FRONTEND_BASE_PORT + offset ))/surveys
      - VITE_AGENT_SERVICE_URL=http://localhost:$(( 4007 + offset ))
    # Mirror the base docker-compose.yml registries-frontend volume list.
    # !override REPLACES the base list, so every mount the base provides must be
    # repeated here — in particular services/registries/api, which codegen reads
    # as its schema. Omitting it makes the container fall back to the stale
    # baked-in schema and codegen fails on any post-build SDL change.
    volumes: !override
      - $repo_root/apps/registries-frontend/src:/apps/registries-frontend/src:cached
      - $repo_root/apps/registries-frontend/test-util:/apps/registries-frontend/test-util:cached
      - $repo_root/services/registries/api:/services/registries/api:cached
      - $repo_root/packages/components/src:/packages/components/src:cached
      - /apps/registries-frontend/node_modules/.vite
    ports: !override
      - "$(( DEV_FRONTEND_BASE_PORT + offset )):$DEV_FRONTEND_BASE_PORT"

  admin:
    profiles: ["disabled"]
  mysql:
    profiles: ["disabled"]

  postgres:
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
    ports: !override
      - "$(( 5432 + offset )):5432"
    volumes: !override
      - database_data_wt_${s}:/var/lib/postgresql/data:rw

  codelist:
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
    volumes: !override
      - $repo_root/services/codelist/src:/app/services/codelist/src
      - $repo_root/services/codelist/api:/app/services/codelist/api
      - $repo_root/services/codelist/prisma:/app/services/codelist/prisma
      - ~/.aws:/root/.aws:ro
    ports: !override
      - "$(( 4005 + offset )):4000"
      - "$(( 50005 + offset )):50051"

  registries:
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
    networks:
      - default
      - admin-bridge
    environment:
      - ALLOWED_ORIGINS=http://localhost:$(( DEV_FRONTEND_BASE_PORT + offset )),http://localhost:3010
      # Raise PROM endpoint rate limit (default 100/min) to the schema cap so
      # local seeders aren't throttled. See services/registries/src/env.ts.
      - PROM_RATE_LIMIT_MAX=10000
      # Stamped into the Helsenorge oppgave's Task.instantiatesUri. Must be the
      # HTTPS ngrok tunnel, not the http://localhost default, or eksternapi
      # rejects the oppgave with FHIR code 2174. Mirrors the patient-bff value.
      - PATIENT_BFF_PUBLIC_URL=${bff_public_url}
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
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
    ports: !override
      - "$(( 4007 + offset )):4000"
AGENT_YAML
    fi

    # patient-bff: defined inline (not via -f services/patient-bff/
    # docker-compose.yml) because compose resolves relative paths from the
    # FIRST compose file's directory, which would break the bff compose's
    # ../.. paths.
    #
    # Host port and redirect_uri are PINNED to 4010 (no worktree offset):
    # NHN's Helsenorge OIDC client only has http://localhost:4010/uthopp/
    # callback on its allow-list, so any other port fails PAR with 204019.
    # Trade-off: only one worktree can run patient-bff at a time.
    # PATIENT_BFF_PUBLIC_URL still picks up NGROK_PATIENT_BFF_URL from
    # ~/.config/dev/.env.local because Helsenorge calls the BFF from the
    # public internet and needs HTTPS.
    if worktree_has_patient_bff; then
        cat >> "$override_file" <<PATIENT_BFF_YAML

  patient-bff:
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
    build:
      context: $repo_root
      dockerfile: ./services/patient-bff/Dockerfile.dev
      args:
        GITHUB_TOKEN: \${GITHUB_TOKEN}
    ports:
      - "4010:4000"
    environment:
      - NODE_ENV=development
      - PORT=4000
      - LOG_LEVEL=debug
      - PRETTY_PRINT=true
      - INCLUDE_STACK_TRACE=true
      - ALLOWED_ORIGINS=http://localhost:$(( 3015 + offset ))
      - PATIENT_BFF_PUBLIC_URL=${bff_public_url}
      - PATIENT_BFF_LOCAL_URL=http://localhost:4010
      - PATIENT_FRONTEND_PROXY_URL=http://patient-frontend:3015
      - PATIENT_BFF_ISSUER=http://patient-bff:4000
      - HELSENORGE_REDIRECT_URI=http://localhost:4010/uthopp/callback
      - HELSENORGE_OIDC_DISCOVERY_URL=https://eksternapi.hn2.test.nhn.no/sts/oidcprov/v3/.well-known/openid-configuration
      - HELSENORGE_CLIENT_ID=3a17b005-b58f-4d3f-8b13-ed0f92aecc0f
      - HELSENORGE_CLIENT_ASSERTION_KMS_KEY_ID=alias/patient-helsenorge-client-assertion-test
      - AWS_PROFILE=test
      - REGISTRIES_GRPC_ADDRESS=registries-service.internal:50052
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_DATABASE=patient_bff
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_APP_USER=postgres
      - POSTGRES_APP_HOST=postgres
      - POSTGRES_APP_PASSWORD=postgres
      - POSTGRES_IAM_AUTH=false
      - AWS_REGION=eu-central-1
      - PATIENT_ASSERTION_KMS_KEY_ID=alias/patient-bff-assertion-local
      - SESSION_ENCRYPTION_KMS_KEY_ID=alias/patient-bff-session-local
      - USE_STUBBED_KMS=true
      - SESSION_IDLE_TIMEOUT_MINUTES=15
      - SESSION_HARD_CAP_MINUTES=60
      - RATE_LIMIT_API_PER_MINUTE=60
      - RATE_LIMIT_UTHOPP_PER_MINUTE=10
    depends_on:
      patient-bff-db-init:
        condition: service_completed_successfully
      registries:
        condition: service_healthy
    volumes:
      - $repo_root/services/patient-bff/src:/app/services/patient-bff/src:cached
      - $repo_root/services/patient-bff/prisma:/app/services/patient-bff/prisma:cached
      - $repo_root/services/registries/api:/app/services/registries/api:cached
      - $repo_root/packages/helseid:/app/packages/helseid:cached
      - ~/.aws:/root/.aws:ro

  patient-bff-db-init:
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
    image: postgres:17
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      PGPASSWORD: postgres
    entrypoint: /bin/sh
    command: >-
      -c "set -e;
      if ! psql -h postgres -U postgres -tAc \"SELECT 1 FROM pg_database WHERE datname='patient_bff'\" | grep -q 1; then
      psql -h postgres -U postgres -c 'CREATE DATABASE patient_bff';
      fi"
PATIENT_BFF_YAML
    fi

    # patient-frontend: no compose file lives in-repo (just a Dockerfile.dev),
    # so the dev script owns the service definition. Mirrors the registries-
    # frontend block: build context = repo root, bind-mount src for HMR.
    if worktree_has_patient_frontend; then
        cat >> "$override_file" <<PATIENT_FRONTEND_YAML

  patient-frontend:
    labels:
      ${DEV_SLOT_LABEL}: "${s}"
      ${DEV_WORKSPACE_LABEL}: "${base_project_name}"
    build:
      context: $repo_root
      dockerfile: ./apps/patient-frontend/Dockerfile.dev
      args:
        GITHUB_TOKEN: \${GITHUB_TOKEN}
    environment:
      - PORT=3015
      - PATIENT_BFF_URL=http://patient-bff:4000
      # MSW defaults to ON in dev (main.tsx) — disable so the app hits the
      # real bff PROM endpoints instead of canned "Smerteskala uke 3" mocks.
      - VITE_USE_MSW=false
    ports:
      - "$(( 3015 + offset )):3015"
    volumes:
      - $repo_root/apps/patient-frontend/src:/apps/patient-frontend/src:cached
PATIENT_FRONTEND_YAML
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

# Renders the templates for THIS workspace only. sync-context.sh does the same
# for every workspace at once; both fill the port table through the shared
# dev_apply_context_ports so the two can't drift.
sync_context_files() {
    local s=$1
    local claude_template="$context_dir/CLAUDE.local.md"
    local agents_template="$context_dir/AGENTS.md"

    if [ ! -f "$claude_template" ]; then
        echo "Warning: CLAUDE.local.md template not found at $claude_template" >&2
    else
        cp "$claude_template" "$claude_local_md"
        dev_apply_context_ports "$claude_local_md" "$s"
    fi

    if [ ! -f "$agents_template" ]; then
        echo "Warning: AGENTS.md template not found at $agents_template" >&2
    else
        cp "$agents_template" "$agents_md"
        dev_apply_context_ports "$agents_md" "$s"
    fi
}

# Teardown restores the context corpus instead of deleting it: CLAUDE.local.md
# and AGENTS.md carry every project rule, not just the port table, and nothing
# else puts them back. sync-context.sh re-renders them from the templates and
# swaps the port section for a start-the-stack note when there is no stack.
restore_context_files() {
    if [ ! -x "$SYNC_CONTEXT" ]; then
        echo "Warning: $SYNC_CONTEXT is not executable; leaving context files as they are." >&2
        return 0
    fi
    "$SYNC_CONTEXT" || echo "Warning: context sync failed; CLAUDE.local.md and AGENTS.md may be stale." >&2
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
        echo "    Frontend:   http://localhost:$DEV_FRONTEND_BASE_PORT/en"
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
            echo "    Frontend:   http://localhost:$(( DEV_FRONTEND_BASE_PORT + offset ))/en"
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
    echo "  up [--slot N] [--include-patient] [--build] [services...]  Start stack (full init flow)"
    echo "  down                        Stop and remove containers"
    echo "  nuke [--yes]                Full teardown (volumes, images, slot)"
    echo "  status                      Show all running stacks"
    echo "  start [services...]         Start stopped containers"
    echo "  <any>                       Passthrough to docker compose"
    exit 1
fi

subcommand="$1"
shift

# Parse flags for up command
slot_override=""
include_patient="false"
nuke_confirmed="false"
if [ "$subcommand" = "up" ]; then
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --slot)
                if [ -z "${2:-}" ]; then
                    echo "Error: --slot requires a value (1-9)" >&2
                    exit 1
                fi
                if ! [[ "$2" =~ ^[1-9]$ ]]; then
                    echo "Error: --slot must be 1-9, got: $2" >&2
                    exit 1
                fi
                slot_override="$2"
                shift 2
                ;;
            --include-patient)
                include_patient="true"
                shift
                ;;
            *)
                break
                ;;
        esac
    done
elif [ "$subcommand" = "nuke" ]; then
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --yes)
                nuke_confirmed="true"
                shift
                ;;
            *)
                break
                ;;
        esac
    done
fi

# Status doesn't need slot resolution or override generation
if [ "$subcommand" = "status" ]; then
    show_status
    exit 0
fi

prerequisites_check

# Every remaining subcommand ends up in docker compose. Say so here rather than
# letting a missing compose file surface as an opaque compose or bash error.
if [ ! -f "$repo_root/docker-compose.yml" ]; then
    echo "Error: no docker-compose.yml in $repo_root." >&2
    echo "dev manages the monorepo's stack and has to run inside a checkout of it." >&2
    exit 1
fi

# Take the slot lock before scanning for a free slot; the up branch releases it
# once the containers carrying the slot label exist.
if [ "$subcommand" = "up" ] && [ "$mode" = "worktree" ]; then
    acquire_slot_lock
fi

resolved_slot=$(resolve_slot)
if ! [[ "$resolved_slot" =~ ^[0-9]$ ]]; then
    echo "Error: unusable slot '$resolved_slot' (expected 0-9)." >&2
    echo "Fix or delete $slot_file, then run 'dev up'." >&2
    exit 1
fi
offset=$(( resolved_slot * 100 ))

if [ "$mode" = "worktree" ]; then
    # Prefix surfaces the slot in Docker Desktop. Lowercase per compose naming rules.
    project_name="wt${resolved_slot}-${base_project_name}"
    echo "Mode: worktree (slot $resolved_slot, offset +$offset)"
else
    echo "Mode: main (default ports)"
fi
echo "Project: $project_name"
if [ "$offset" -gt 0 ]; then
    echo "Frontend: http://localhost:$(( DEV_FRONTEND_BASE_PORT + offset ))/en"
fi
echo

default_services=()
while IFS= read -r service; do
    [ -n "$service" ] && default_services+=("$service")
done < <(available_services registries-frontend postgres codelist registries agent)

# Optional services that branches opt into by adding files to the worktree.
# patient-bff comes from services/patient-bff/docker-compose.yml; patient-frontend
# is generated into the override file. Both ride the slot's +offset like every
# other service.
if worktree_has_patient_bff; then
    default_services+=(patient-bff)
fi
if worktree_has_patient_frontend; then
    default_services+=(patient-frontend)
fi

case "$subcommand" in
    up)
        requested_services=()
        while IFS= read -r service; do
            [ -n "$service" ] && requested_services+=("$service")
        done < <(collect_compose_services "$@")
        if [ "${#requested_services[@]}" -eq 0 ]; then
            requested_services=(${default_services[@]+"${default_services[@]}"})
        fi
        require_services

        needs_admin_mock=false
        if service_list_contains "registries" "${requested_services[@]}"; then
            needs_admin_mock=true
            check_admin_mock
        fi
        [ "$mode" = "worktree" ] && save_slot "$resolved_slot"

        # Clean up stopped containers before network setup — their stale network
        # references would prevent network removal and cause start failures.
        cleanup_stale_containers

        # Create per-slot bridge network so compose services can reach admin-mock
        if [ "$mode" = "worktree" ] && [ "$needs_admin_mock" = true ]; then
            # Remove stale default network from a previous project that used this slot
            docker network rm "default-network-wt-${resolved_slot}" 2>/dev/null || true
            docker network create "admin-bridge-wt-${resolved_slot}" 2>/dev/null || true
            docker network connect "admin-bridge-wt-${resolved_slot}" admin-mock 2>/dev/null || true
        fi

        generate_override "$resolved_slot"

        # Materialize the containers — and with them the dev-slot label another
        # run reads to see this slot as taken — before releasing the slot lock.
        # `create` takes services only; the up-only flags in "$@" are not valid
        # here, and `up` below still applies them.
        if [ "$mode" = "worktree" ]; then
            dc create "${requested_services[@]}"
            release_slot_lock
        fi

        if [ "$#" -gt 0 ]; then
            dc up "$@" -d --wait
        else
            dc up -d --wait "${requested_services[@]}"
        fi

        # Always sync context files so Claude has correct ports
        sync_context_files "$resolved_slot"

        if service_list_contains "registries" "${requested_services[@]}"; then
            run_seed
            write_env_files "$resolved_slot"
        fi

        if service_list_contains "registries-frontend" "${requested_services[@]}"; then
            echo "Stack is running at http://localhost:$(( DEV_FRONTEND_BASE_PORT + offset ))/en/registries"
        else
            echo "Stack is running."
        fi
        ;;

    down)
        generate_override "$resolved_slot"
        dc down "$@"
        if [ "$mode" = "worktree" ]; then
            docker network disconnect "default-network-wt-${resolved_slot}" admin-mock 2>/dev/null || true
            docker network rm "default-network-wt-${resolved_slot}" 2>/dev/null || true
        fi
        restore_context_files
        remove_env_files
        ;;

    nuke)
        echo "This will remove all containers, volumes, and images for this stack."
        if [ -t 0 ]; then
            read -r -p "Are you sure? (y/N): " confirm
            echo
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Nuke cancelled."
                exit 0
            fi
        elif [ "$nuke_confirmed" != "true" ]; then
            # No terminal to prompt on (script, agent, pipe). Deleting volumes —
            # in main mode, the main checkout's postgres data — needs to be asked
            # for on purpose.
            echo "Error: stdin is not a terminal, so there is nothing to confirm on." >&2
            echo "Re-run as 'dev nuke --yes' if you really mean to remove the volumes and images." >&2
            exit 1
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
        remove_env_files
        rm -rf "$tmp_dir"
        restore_context_files
        echo
        echo "Nuke complete."
        ;;

    start)
        requested_services=()
        while IFS= read -r service; do
            [ -n "$service" ] && requested_services+=("$service")
        done < <(collect_compose_services "$@")
        if [ "${#requested_services[@]}" -eq 0 ]; then
            requested_services=(${default_services[@]+"${default_services[@]}"})
        fi
        require_services

        needs_admin_mock=false
        if service_list_contains "registries" "${requested_services[@]}"; then
            needs_admin_mock=true
            check_admin_mock
        fi
        cleanup_stale_containers

        if [ "$mode" = "worktree" ] && [ "$needs_admin_mock" = true ]; then
            docker network rm "default-network-wt-${resolved_slot}" 2>/dev/null || true
            docker network create "admin-bridge-wt-${resolved_slot}" 2>/dev/null || true
            docker network connect "admin-bridge-wt-${resolved_slot}" admin-mock 2>/dev/null || true
        fi

        generate_override "$resolved_slot"
        if [ "$#" -gt 0 ]; then
            dc up -d "$@"
        else
            dc up -d "${requested_services[@]}"
        fi
        ;;

    *)
        # Pure passthrough to docker compose
        generate_override "$resolved_slot"
        dc "$subcommand" "$@"
        ;;
esac
