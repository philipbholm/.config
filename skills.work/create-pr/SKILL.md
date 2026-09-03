---
name: create-pr
description: Create or open a Ledidi pull request from implementation through checks. Use when the user asks to create or open a PR in the Ledidi monorepo.
---

# Create a Ledidi pull request

Run the whole flow for “create a PR that …”. For a bare “create PR”, resume at
the first unmet precondition. A preceding grilling or specification session
does not consume the request; start this flow when the user confirms the work.

1. For a larger effort, write `.scratch/<slug>/spec.md` in the main checkout.
   A smaller change needs no spec file. Keep discarded alternatives and future
   work for the final report, not the pull request body.
2. Load the `worktree` skill and create and prepare the branch and worktree.
   Effort files remain in the main checkout's `.scratch/`; reach them by
   absolute path.
3. Load the `dev-stack` skill. Start PostgreSQL for backend tests or the full
   stack for browser work and E2E.
4. Implement the change and run the suites for every workspace changed. Run
   E2E only when the user asks for E2E or browser verification requires it.
5. Run the `code-review` skill before opening the pull request. Fix its findings
   as ordinary commits.
6. Commit, push, and open a draft with `gh pr create --draft`. Use a gitmoji
   title and add `risk:standard`; labels beyond that require approval. Open the
   pull request URL in the browser.
7. Run `gh pr checks <number>`. Fix and push a red `pr-checks`, because it blocks
   master. Report every other failing check.
8. Report the worktree path, branch, running containers and ports, suites run,
   suites the stack could not support, review outcome, pull request URL, and
   check state.

## Pull request body

Use `## Why` and `## What` as the only sections and apply the global pull
request writing rules.

- `## Why` uses three or four sentences for the problem and the outcome.
- `## What` groups only the reviewer-relevant behavior, decisions, risks,
  setup, and verification. The number of bullets follows the number of ideas,
  not the number of files.
- Quote new user-facing strings when the wording matters to review.

For product code, update
`services/registries/docs/story-map/src/data/story-map.json` when user-visible
behavior changes. Otherwise tick the **Story map reviewed** checkbox added by
the bot.

If a step fails, stop there. Name the failed step and the state of the
worktree. Leave the worktree and stack standing so a later session keeps the
completed setup.
