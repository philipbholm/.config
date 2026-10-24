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
  story <slot>                                Start Storybook for a checkout slot
  test e2e [--shell] -- [arguments]            Run registries E2E with this stack's URLs
  stack up [services...]                      Start this checkout's services
  stack down                                  Stop services; keep databases
  stack destroy [--yes]                       Delete services, databases and slot
  stack list                                  List running stacks across checkouts
  stack expose                                Publish this stack through public tunnels
  context render [--all-worktrees]             Render this checkout's agent instructions
  context show                               Show checkout, ports and agent instruction paths
  context check                              Check rendered context and shared skill links
  session search [text] [--repo path]          Search local Claude Code and Codex user messages
  agent-config apply --profile work           Apply work configuration to installed agents
  browser launch-debug                        Launch the separate debug browser on :9222

Use dev <thing> --help or dev <thing> <action> --help for details.
Help never starts services, installs dependencies, or writes configuration.
HELP
            ;;
        story)
            cat <<'HELP'
Usage: dev story <slot>
       story <slot>

Start registries Storybook in the checkout assigned to slot 1-9. Slot 0 uses
the main checkout. Missing frontend dependencies are prepared on the first run.
The default port is 6009 plus the slot; an occupied port advances to the next
free port. Storybook stays in the foreground, and Ctrl-C stops it.
HELP
            ;;
        worktree|worktree-create|worktree-destroy)
            cat <<'HELP'
Usage: dev worktree create <name> <branch> [start-point]
       dev worktree destroy

Create places the checkout in <repo>/.worktrees/<name>. Existing branches keep
their commits; new branches start at start-point or HEAD. It does not fetch.
Ledidi checkouts receive AGENTS.md without dependency setup.

Destroy acts on the current worktree. It removes the checkout and its stack,
including its databases and saved port slot. The Git branch remains.
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
No services are started. With no workspace arguments, nothing is prepared.
HELP
            ;;
        test)
            cat <<'HELP'
Usage: dev test e2e [--shell] -- [Playwright arguments]

Start registries, codelist and their dependencies.
Check GraphQL readiness and run the registries package's test:e2e script.
--shell selects test:e2e:shell. Arguments after -- go to Playwright unchanged.
Browser requests and fixture setup use this checkout's API URL, overriding
inherited URL variables. Preview ports are 3004 and (with --shell) 3010 plus
the stack slot offset. Occupied preview ports fail before frontend startup.
Prepare frontend dependencies first with dev workspace prepare; this command
does not install packages. All three agent harnesses use the same command.
HELP
            ;;
        stack)
            cat <<'HELP'
Usage: dev stack <action> [arguments]

Services run as processes on this Mac. All checkouts share one PostgreSQL on
localhost:5432 and one admin mock on ports 4054 and 50004.

  up [--slot N] [services...]
      Start services and wait until they are ready. Services: registries,
      registries-frontend, codelist, and postgres for the database alone.
      No services means registries and registries-frontend. The first start
      for a set of migrations builds a template database; later checkouts copy
      it with the Analysis test registry already seeded. Also writes
      services/registries/.env.test.local for the backend suite.
      --slot selects worktree slot 1-9.
  down     Stop this checkout's services; keep its databases. stop is an alias.
  destroy [--yes]
      Stop the services and delete this checkout's databases and slot.
      Prompts in a terminal; requires --yes for non-interactive execution.
  list     List running stacks across checkouts; works outside a repository.
  ps       Show this checkout's services, ports and log files.
  logs [-f] [-n N] [services...]
      Print service logs; -f follows them.
  restart [services...]
      Restart services; no services means the running ones.
  psql [--test] [psql arguments]
      Open this checkout's database, or its test database with --test.
  reap [--dry-run]
      Stop stacks idle for two hours, and delete the stack data and databases
      of checkouts that no longer exist, plus unused template databases.
      A launch agent runs this every 15 minutes.
  expose   Publish this stack's frontend and API through public tunnels.
HELP
            ;;
        stack-expose)
            cat <<'HELP'
Usage: dev stack expose

Expose this checkout's frontend and API to the public internet through
Cloudflare tunnels. Requires a running stack and cloudflared.
Restarts registries and the frontend with tunnel URLs while running; restores
their configuration when stopped. Keep this command running; Ctrl-C closes it.
HELP
            ;;
        context|context-render)
            cat <<'HELP'
Usage: dev context render [--all-worktrees]
       dev context show [--json]
       dev context check

Render AGENTS.md from the Ledidi template with stack ports. Also install the
post-checkout hook that renders AGENTS.md into each new worktree, whichever
tool creates it.
By default, update only the current Ledidi checkout. --all-worktrees updates
the main checkout and all registered Ledidi worktrees. Starts no services.
Show reports the command's actual checkout and installed instruction/skill paths.
Check reports stale rendered files and broken shared links; exit 1 means a problem.
Show and check do not rewrite context, install skills, or start services.
HELP
            ;;
        session)
            cat <<'HELP'
Usage: dev session search [text] [--repo path] [--branch name] [--ticket id]
                          [--since YYYY-MM-DD] [--until YYYY-MM-DD]
                          [--harness all|claude|codex] [--limit N] [--json]

Search local user messages for the current repository, including worktrees and
archived Codex sessions. No network access. Use search --help for filter details.
The command runs from Claude Code, Codex, Cursor Agent, or a terminal; it reads
Claude Code and Codex transcript formats only.
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
