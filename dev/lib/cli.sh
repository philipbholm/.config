#!/bin/bash
set -euo pipefail

dev_cli_error() {
    echo "Error: $1. See dev --help." >&2
    exit 2
}

dev_help_if_requested() {
    local topic=$1
    shift
    local argument
    for argument in "$@"; do
        case "$argument" in
            --) return 0 ;;
            --help|-h) dev_help "$topic"; exit 0 ;;
        esac
    done
}

dev_help() {
    case "$1" in
        dev)
            cat <<'HELP'
Usage: dev <thing> <action> [arguments]

  worktree create <name> <branch> [start-point]  Create a checkout and agent context
  worktree destroy                            Delete this worktree and its stack data
  workspace prepare <workspace> ...           Install dependencies and generate types
  stack up [services...]                      Start this checkout's services
  stack down                                  Remove containers; keep database volumes
  stack destroy [--yes]                       Delete containers, volumes, images and slot
  stack list                                  List running stacks across checkouts
  stack expose                                Publish this stack through public tunnels
  context render [--all-worktrees]             Render this checkout's agent instructions
  agent-config apply --profile work           Apply work configuration to installed agents
  browser launch-debug                        Launch the separate debug browser on :9222

Use dev <thing> --help or dev <thing> <action> --help for details.
Help never starts services, installs dependencies, or writes configuration.
HELP
            ;;
        worktree|worktree-create|worktree-destroy)
            cat <<'HELP'
Usage: dev worktree create <name> <branch> [start-point]
       dev worktree destroy

Create places the checkout in <repo>/.worktrees/<name>. Existing branches keep
their commits; new branches start at start-point or HEAD. It does not fetch.
Ledidi checkouts receive AGENTS.md and CLAUDE.local.md without dependency setup.

Destroy acts on the current worktree. It removes the checkout and its stack,
including database volumes, images and saved port slot. The Git branch remains.
It refuses the main checkout and worktrees with uncommitted changes.
HELP
            ;;
        workspace|workspace-prepare)
            cat <<'HELP'
Usage: dev workspace prepare <workspace> [workspace ...]

A workspace is a directory with its own package.json, such as services/registries.
Paths are relative to the checkout root. Only named workspaces are prepared.
Install with npm ci when a lockfile exists, otherwise npm install without a
lockfile. Then run each selected workspace's generate script, if present.
No containers are started. With no workspace arguments, nothing is prepared.
HELP
            ;;
        stack)
            cat <<'HELP'
Usage: dev stack <action> [arguments]

  up [--slot N] [--include-patient] [--build] [services...]
      Create or update services and wait for readiness. Registries also gets
      codelist seeding and its test environment file. No services means the
      default registries stack. --slot selects worktree slot 1-9.
      --include-patient opts into patient services (shared host port 4010).
  down     Remove this stack's containers and network; keep database volumes.
  destroy [--yes]
      Delete this stack's containers, database volumes, local images and slot.
      Prompts in a terminal; requires --yes for non-interactive execution.
  list     List running stacks across checkouts; works outside a repository.
  expose   Publish this stack's frontend and API through public tunnels.

Compose actions: logs, exec, ps, build, stop, restart, config, pull, images,
top, events, port, run. Their arguments are passed to Docker Compose.
Use -- before a forwarded command whose arguments include --help.
Use dev stack up to start services; there is no separate start workflow.
HELP
            ;;
        stack-expose)
            cat <<'HELP'
Usage: dev stack expose

Expose this checkout's frontend and API to the public internet through
Cloudflare tunnels. Requires an existing stack and cloudflared.
Recreates the affected containers with tunnel URLs while running; restores
their configuration when stopped. Keep this command running; Ctrl-C closes it.
HELP
            ;;
        context|context-render)
            cat <<'HELP'
Usage: dev context render [--all-worktrees]

Render AGENTS.md and CLAUDE.local.md from the Ledidi template with stack ports.
By default, update only the current Ledidi checkout. --all-worktrees updates
the main checkout and all registered Ledidi worktrees. Starts no services.
HELP
            ;;
        agent-config|agent-config-apply)
            cat <<'HELP'
Usage: dev agent-config apply --profile work

Merge tracked base configuration with work overlays and replace the installed
Claude, Codex and Cursor configuration files. Keep changed regular files as
.bak backups. The work profile must be selected explicitly.
HELP
            ;;
        browser|browser-launch-debug)
            cat <<'HELP'
Usage: dev browser launch-debug

Launch Chrome (or Brave) with a separate persistent debug profile on :9222.
Leave an existing listener running. BROWSER_APP can select another Chromium binary.
This is not the in-app browser and does not use your regular browser profile.
HELP
            ;;
        *) dev_cli_error "unknown help topic: $1" ;;
    esac
}
