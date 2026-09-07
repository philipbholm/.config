# Resource inspection and removal

## Read-only inventory

Start with `git worktree list --porcelain`, `docker context show`,
`docker ps -a`, `docker image ls -a --no-trunc`, `docker volume ls`,
`docker network ls`, and `docker system df`. Use `docker system df -v` when
per-resource usage changes a recommendation. If Docker or GitHub is unavailable,
report the missing evidence; an empty or failed query is not proof of absence.

Inspect only the needed metadata: container image IDs, mounts and labels;
image IDs, tags and labels; volume labels and consumers; network endpoints.
Avoid dumping container environments or rendered Compose configuration, which
can contain credentials. Some images have no labels; treat those as unknown
ownership rather than excluding them from the inventory.

Use the identity functions in
[checkout.sh](/Users/philip/.config/dev/lib/checkout.sh) to resolve checkout IDs, saved
slots and stack-state paths. Read those values without calling slot-pruning or
allocation functions. Match Docker's `com.docker.compose.project` and working
directory labels with checkout identity and saved Compose files. Container
labels `com.ledidi.dev-workspace` and `com.ledidi.dev-slot` provide additional
evidence. A name prefix or slot number alone is not ownership proof: slots are
reused, and different checkout paths can have the same basename.

Compare images and volumes against all containers, including stopped ones.
An unused resource is not necessarily stale: an open-PR stack may need it again.
Keep `admin-mock`, shared base images, shared networks, and unrelated projects
outside automatic cleanup. Anonymous volumes and unattributed images need
their own explicit selection; do not infer a merged PR from their age.

## Worktree and stack teardown

Read [worktree-destroy.sh](/Users/philip/.config/dev/worktree-destroy.sh) and the teardown
path in [stack.sh](/Users/philip/.config/dev/stack.sh) before relying on their target
resolution. They must resolve to the inventoried checkout and Compose project.
If a saved slot is now used by another stack or checkout IDs collide, keep the
target and report the conflict instead of invoking a helper on guessed state.

The worktree helper also prunes stale Git registrations and saved slot files
across checkouts. Include those side effects in the inventory. If they would
remove unapproved entries, report the scope conflict instead of invoking it.

`dev worktree destroy` checks for saved slots or matching containers before
tearing down a stack. With neither present, images and volumes can remain.
`dev stack destroy` uses `docker compose down -v --rmi local --remove-orphans`;
this does not promise removal of every old image, anonymous volume, or resource
from a previous slot. Always inspect leftovers after the helper returns.

## Leftovers after manual deletion or teardown

Deleting containers does not automatically remove their images, persistent
volumes, or build cache. Docker's "reclaimable" figure describes usage, not
permission to delete. Image and cache sizes can overlap through shared layers.
See [Docker resource pruning](https://docs.docker.com/engine/manage-resources/pruning/)
and [Compose teardown](https://docs.docker.com/reference/cli/docker/compose/down/).

For resources proven exclusive to an automatically eligible merged worktree,
or explicitly selected by number, use narrow Docker removal commands when no
owning checkout remains or the dev helper leaves them behind. This is a
cleanup-only exception to the normal dev-stack command routing.

- Remove only the inventoried containers, without force-removing newly active
  containers. Recheck volume and image consumers afterwards.
- Remove unused images by exact ID or selected tag with `docker image rm`,
  without force. If an image has tags or consumers outside the selected group,
  preserve the shared image; remove only an approved tag when appropriate.
- Remove only selected volume names with `docker volume rm`, after confirming
  no container references them and their data loss was authorized.
- Remove only selected networks with no endpoints. A slot network with a
  shared `admin-mock` endpoint is not an orphan to disconnect blindly.
- Remove saved stack state only at its validated exact path after resource
  cleanup. Preserve unique files and any state now owned by another checkout.

Orphans without a proven merged-worktree association belong in the numbered
list, even when they look old. Leave branches untouched. A missing directory
does not authorize broad worktree pruning; inspect prunable entries and use
targeted Git cleanup only for the approved registration.

Build cache is separate from images and may serve multiple projects. Report
its size, but require a separate explicit selection with a named builder and
clear scope before removing any cache. Never substitute `docker system prune`,
global image or volume pruning, or `git clean -fdx` for the approved targets.
