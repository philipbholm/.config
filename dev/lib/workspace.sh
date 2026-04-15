#!/bin/bash

dev_worktree_base() {
    printf '%s\n' "${WORKTREE_BASE:-$HOME/work/worktrees}"
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

dev_worktree_raw_key_for_repo() {
    local repo_root=$1
    local branch
    local worktree_base

    branch=$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
    if [ -n "$branch" ]; then
        printf '%s\n' "$branch"
        return
    fi

    worktree_base=$(dev_worktree_base)
    case "$repo_root" in
        "$worktree_base"/*) printf '%s\n' "${repo_root#"$worktree_base"/}" ;;
        *) basename "$repo_root" ;;
    esac
}

dev_workspace_id_for_repo() {
    local repo_root=$1

    if dev_is_worktree_repo "$repo_root"; then
        local raw_key
        local repo_family
        local slug
        local hash

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

dev_slot_reserved_by_other_repo() {
    local repo_root=$1
    local slot=$2
    local own_slot_file
    local candidate
    local candidate_slot

    own_slot_file=$(dev_slot_file_for_repo "$repo_root")

    while IFS= read -r candidate; do
        [ -n "$candidate" ] || continue
        [ "$candidate" = "$own_slot_file" ] && continue

        candidate_slot=$(tr -d '[:space:]' < "$candidate")
        if [ "$candidate_slot" = "$slot" ]; then
            return 0
        fi
    done < <(dev_list_slot_files)

    return 1
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
