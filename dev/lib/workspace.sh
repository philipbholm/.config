#!/bin/bash

DEV_SLOT_LABEL="com.ledidi.dev-slot"
DEV_WORKSPACE_LABEL="com.ledidi.dev-workspace"

# New worktrees live inside the repo at <repo>/.worktrees. The location belongs
# to the repository workflow, not to any one agent harness. WORKTREE_BASE
# overrides it for tests.
dev_worktree_base_for_repo() {
    printf '%s\n' "${WORKTREE_BASE:-${1%/}/.worktrees}"
}

# Include Claude-era worktrees while they still exist. New worktrees always use
# dev_worktree_base_for_repo; this list exists so context sync and teardown keep
# working until the old checkouts are removed normally.
dev_worktree_bases_for_repo() {
    local repo_root=${1%/}

    if [ -n "${WORKTREE_BASE:-}" ]; then
        printf '%s\n' "$WORKTREE_BASE"
        return
    fi

    printf '%s\n' "$repo_root/.worktrees"
    if [ -d "$repo_root/.claude/worktrees" ]; then
        printf '%s\n' "$repo_root/.claude/worktrees"
    fi
}

dev_stacks_dir() {
    printf '%s\n' "${DEV_STACKS_DIR:-$HOME/work/.dev-stacks}"
}

dev_slugify() {
    local slug
    slug=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed \
        -e 's|/|-|g' \
        -e 's|[^a-z0-9_-]|-|g' \
        -e 's|--*|-|g' \
        -e 's|^-||' \
        -e 's|-$||')

    if [ -n "$slug" ]; then
        printf '%s\n' "$slug"
    else
        printf '%s\n' "workspace"
    fi
}

dev_hash_string() {
    printf '%s' "$1" | cksum | awk '{print $1}'
}

dev_is_worktree_repo() {
    [ -f "$1/.git" ]
}

dev_git_common_dir_abs() {
    local repo_root=$1
    local common_dir

    common_dir=$(git -C "$repo_root" rev-parse --git-common-dir 2>/dev/null) || return 1
    case "$common_dir" in
        /*) printf '%s\n' "$common_dir" ;;
        *) (cd "$repo_root/$common_dir" >/dev/null 2>&1 && pwd -P) ;;
    esac
}

dev_repo_family_name() {
    local repo_root=$1
    local common_dir

    common_dir=$(dev_git_common_dir_abs "$repo_root") || {
        basename "$repo_root"
        return
    }

    basename "$(dirname "$common_dir")"
}

# Stack identity for a worktree. Keyed on the directory name, not the branch:
# switching branches inside a worktree must not change which Docker stack,
# slot file, and ports it owns.
dev_worktree_raw_key_for_repo() {
    local repo_root=$1

    basename "$repo_root"
}

dev_workspace_id_for_repo() {
    local repo_root=$1

    if dev_is_worktree_repo "$repo_root"; then
        local raw_key

        raw_key=$(dev_worktree_raw_key_for_repo "$repo_root")
        dev_slugify "$raw_key"
    else
        dev_slugify "$(basename "$repo_root")"
    fi
}

dev_stack_dir_for_repo() {
    local repo_root=$1
    printf '%s/%s\n' "$(dev_stacks_dir)" "$(dev_workspace_id_for_repo "$repo_root")"
}

dev_slot_file_for_repo() {
    local repo_root=$1
    printf '%s/worktree-slot\n' "$(dev_stack_dir_for_repo "$repo_root")"
}

dev_list_slot_files() {
    local stacks_dir
    stacks_dir=$(dev_stacks_dir)

    [ -d "$stacks_dir" ] || return 0

    find "$stacks_dir" -mindepth 2 -maxdepth 2 -type f -name worktree-slot -print 2>/dev/null | sort
}

dev_prune_stale_slot_files() {
    # Removes slot files whose workspace has no matching containers in Docker.
    # No-op if the Docker daemon is unreachable, to avoid wiping valid state.
    if ! docker info >/dev/null 2>&1; then
        return 0
    fi

    local slot_file workspace slot containers

    while IFS= read -r slot_file; do
        [ -n "$slot_file" ] || continue
        [ -f "$slot_file" ] || continue

        workspace=$(basename "$(dirname "$slot_file")")
        slot=$(tr -d '[:space:]' < "$slot_file" 2>/dev/null || true)

        if [ -z "$slot" ]; then
            rm -f "$slot_file"
            continue
        fi

        containers=$(docker ps -aq \
            --filter "label=${DEV_WORKSPACE_LABEL}=${workspace}" \
            --filter "label=${DEV_SLOT_LABEL}=${slot}" 2>/dev/null)

        if [ -z "$containers" ]; then
            rm -f "$slot_file"
        fi
    done < <(dev_list_slot_files)
}

dev_clear_stale_slot_files() {
    local repo_root=$1
    local slot=$2
    local own_slot_file
    local candidate
    local candidate_slot

    own_slot_file=$(dev_slot_file_for_repo "$repo_root")

    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        [ "$candidate" = "$own_slot_file" ] && continue

        candidate_slot=$(tr -d '[:space:]' < "$candidate" 2>/dev/null || true)
        if [ "$candidate_slot" = "$slot" ]; then
            rm -f "$candidate"
        fi
    done < <(dev_list_slot_files)
}

dev_existing_slot_file_for_repo() {
    local repo_root=$1
    local raw_key
    local slug
    local candidate

    candidate=$(dev_slot_file_for_repo "$repo_root")
    if [ -f "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    raw_key=$(dev_worktree_raw_key_for_repo "$repo_root")
    slug=$(dev_slugify "$raw_key")

    for candidate in \
        "$(dev_stacks_dir)/${raw_key}/worktree-slot" \
        "$(dev_stacks_dir)/${slug}/worktree-slot" \
        "$(dev_stacks_dir)/$(basename "$repo_root")/worktree-slot"
    do
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    return 1
}

dev_slot_for_repo() {
    local repo_root=$1
    local slot_file

    if ! dev_is_worktree_repo "$repo_root"; then
        printf '0\n'
        return 0
    fi

    slot_file=$(dev_existing_slot_file_for_repo "$repo_root" 2>/dev/null || true)
    if [ -n "$slot_file" ] && [ -f "$slot_file" ]; then
        cat "$slot_file"
    else
        printf '0\n'
    fi
}

# Host ports the main checkout (slot 0) publishes. A worktree on slot N publishes
# each of them at +N*100. Shared so the compose overrides and the context
# templates cannot drift apart.
DEV_FRONTEND_BASE_PORT=3003
DEV_ROUTER_BASE_PORT=4000
DEV_CODELIST_BASE_PORT=4005
DEV_CODELIST_GRPC_BASE_PORT=50005
DEV_REGISTRIES_BASE_PORT=4006
DEV_REGISTRIES_GRPC_BASE_PORT=50006
DEV_AGENT_BASE_PORT=4007
DEV_POSTGRES_BASE_PORT=5432

# Fill the {{...PORT}} placeholders in a copied context file with the ports a
# slot publishes. dev.sh calls this for the single worktree it just started;
# sync-context.sh calls it for every workspace it rewrites.
#
#   dev_apply_context_ports <file> <slot>
#
# Edits <file> in place. Returns 1 and leaves the file untouched if it does not
# exist or the slot is not 0-9.
dev_apply_context_ports() {
    local file=$1
    local slot=$2
    local offset

    if [ ! -f "$file" ]; then
        echo "Error: context file not found: $file" >&2
        return 1
    fi
    if ! [[ "$slot" =~ ^[0-9]$ ]]; then
        echo "Error: unusable slot '$slot' for $file (expected 0-9)" >&2
        return 1
    fi
    offset=$(( slot * 100 ))

    local replacements=(
        -e "s|{{FRONTEND_PORT}}|$(( DEV_FRONTEND_BASE_PORT + offset ))|g"
        -e "s|{{ROUTER_PORT}}|$(( DEV_ROUTER_BASE_PORT + offset ))|g"
        -e "s|{{POSTGRES_PORT}}|$(( DEV_POSTGRES_BASE_PORT + offset ))|g"
        -e "s|{{CODELIST_PORT}}|$(( DEV_CODELIST_BASE_PORT + offset ))|g"
        -e "s|{{CODELIST_GRPC_PORT}}|$(( DEV_CODELIST_GRPC_BASE_PORT + offset ))|g"
        -e "s|{{REGISTRIES_PORT}}|$(( DEV_REGISTRIES_BASE_PORT + offset ))|g"
        -e "s|{{REGISTRIES_GRPC_PORT}}|$(( DEV_REGISTRIES_GRPC_BASE_PORT + offset ))|g"
        -e "s|{{AGENT_PORT}}|$(( DEV_AGENT_BASE_PORT + offset ))|g"
    )

    if [[ "$OSTYPE" == darwin* ]]; then
        sed -i '' "${replacements[@]}" "$file"
    else
        sed -i "${replacements[@]}" "$file"
    fi
}
