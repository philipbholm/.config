# Verify with a seeded registry

Use the current worktree's rendered URL and the requested registry. Confirm the
browser's signed-in user and active workspace can see the registry. A successful
seed command does not prove that the browser can use its data. Inspect ownership,
workspace membership, and permissions when the registry is missing; keep useful
data while diagnosing.

Exercise the requested interaction through the UI. For a mutation such as
creating, renaming, moving, or resizing a card, reload the page and confirm the
result persists. Inspect console errors and failed network requests, including
save failures hidden by optimistic UI updates. Record what passed and what was
not exercised.

Choose visual cases relevant to the change: Norwegian and English copy, long
chart labels, small cards, and the registries page inside the shell navbar.
Standalone rendering cannot verify shell-dependent overflow. If the required
shell environment is unavailable, report that limit rather than claiming the
layout passed.

Return the registry URL and the observed result. Leave the useful seeded demo
and its stack available unless cleanup was requested. Use `cleanup-dev` when
teardown is in scope.
