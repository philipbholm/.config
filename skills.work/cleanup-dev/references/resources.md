# Resource inspection and removal

## What a stack owns

Services run as host processes. One shared PostgreSQL and one admin mock serve
every checkout; they are never cleanup targets. Each checkout owns:

| Resource | Where |
|----------|-------|
| Stack state: slot, pid files, logs | `~/work/.dev-stacks/<checkout-id>/` |
| App database | `registries_<checkout id with _ for ->` |
| Test database | `registries_test_<id>` |
| Codelist database | `codelist_<id>`, when codelist ran |
| Test environment file | `services/registries/.env.test.local` in the checkout |

`dev stack reap` runs every 15 minutes. It already removes the stack state and
databases of checkouts that no longer exist, stops stacks idle for two hours,
and drops template databases (`registries_tpl_*`, `registries_seed_*`) that no
checkout's migrations use. `~/work/.dev-stacks/.shared/node_modules/` caches
dependency installs by lockfile; deleting it costs only reinstall time.

## Read-only inventory

Start with `git worktree list --porcelain`, `dev stack list`, and
`dev stack reap --dry-run`. List databases with
`/opt/homebrew/opt/postgresql@17/bin/psql -h localhost -U postgres -Atc 'select datname from pg_database'`.
Use the identity functions in
[checkout.sh](/Users/philip/.config/dev/lib/checkout.sh) to resolve checkout IDs and
stack-state paths. A saved slot number alone is not ownership proof: slots are
reused, and different checkout paths can have the same basename. The `checkout`
file in a stack directory records the path that owns it.

## Worktree and stack teardown

Read [worktree-destroy.sh](/Users/philip/.config/dev/worktree-destroy.sh) and
`command_destroy` in [stack.py](/Users/philip/.config/dev/lib/stack.py) before relying
on their target resolution. They must resolve to the inventoried checkout. If
checkout IDs collide, keep the target and report the conflict: the helpers
drop every database named after the shared ID.

The worktree helper also runs `git worktree prune`, which removes stale Git
registrations across checkouts. Include that side effect in the inventory. If
it would remove unapproved entries, report the scope conflict instead of
invoking it.

## Legacy Docker resources

Stacks used to run in Docker. Stack directories without a `checkout` file,
containers and volumes named `wt<N>-<checkout-id>-*`, the `admin-mock`
container, and Docker build cache are left from that setup. No dev command
manages them any more. Inventory them with `docker ps -a`, `docker volume ls`,
`docker image ls` and `docker system df` when Docker is running, and list them
as their own numbered groups. Remove only selected resources by exact name
with `docker rm`, `docker volume rm` and `docker image rm`, without force.
Build cache needs its own explicit selection. Never substitute
`docker system prune`, global pruning, or `git clean -fdx` for the approved
targets.
