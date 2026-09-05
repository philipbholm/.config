---
name: create-pr
description: Create or open a Ledidi pull request from implementation through checks. Use when the user asks to create or open a PR in the Ledidi monorepo.
---

# Create a Ledidi pull request

Run the whole flow for “create a PR that …”. For a bare “create PR”, resume at
the first unmet precondition. A preceding grilling or specification session
does not consume the request; start this flow when the user confirms the work.

1. Load `write-pr` for PR scope and message rules. For a larger effort, write
   `.scratch/<slug>/spec.md` in the main checkout.
   A smaller change needs no spec file. Keep discarded alternatives and future
   work for the final report, not the pull request body.
2. Load the `worktree` skill and create and prepare the branch and worktree.
   Effort files remain in the main checkout's `.scratch/`; reach them by
   absolute path.
3. Load `verify-change` for check scope and failure handling, and
   `coding-standards` before changing code. Load `dev-stack` if checks need setup.
4. Implement the change and verify it under `verify-change`.
5. Run the `code-review` skill before opening the pull request. Fix its findings
   as ordinary commits.
6. Load `write-commit`, commit, and push under `verify-change`. Open a draft
   with `gh pr create --draft`, using the title and body rules from `write-pr`.
   Add `risk:standard`; labels beyond that require approval. Open the pull
   request URL in the browser.
7. Load `finish-pr` and complete its monitoring and repair loop.
8. Report the worktree path, branch, running containers and ports, suites run,
   suites the stack could not support, review outcome, pull request URL, and
   check state.

## Product behavior

For product code, update
`services/registries/docs/story-map/src/data/story-map.json` when user-visible
behavior changes. Otherwise tick the **Story map reviewed** checkbox added by
the bot.

Recover check failures under `verify-change` before the PR exists and under
`finish-pr` after it exists. If progress requires user input or external
action, report the blocker and the state of the worktree. Leave the worktree
and stack standing so a later session keeps the completed setup.
