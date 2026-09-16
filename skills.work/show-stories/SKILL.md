---
name: show-stories
description: Show added or changed Storybook stories locally for a PR or the current branch. Use when the user says "show stories" or asks to preview a change's stories in a browser. Opens the stories and returns a linked change table.
---

# Show stories

Run Storybook from the requested checkout, open the added and changed stories
in the user's browser, and return a table linking each story to its local URL.
This is a preview workflow; source edits need separate authorization.

## Select the change

Use the PR, branch, or diff named in the request or active conversation. With
no explicit target, use the current branch and include its uncommitted changes.
Ask for a target only when the checkout and conversation provide none.

For a PR, read its base branch, head branch, head commit, and changed files.
Load `worktree` before entering or creating a Ledidi worktree. Reuse the PR's
existing worktree and confirm its HEAD matches the PR. Preserve local edits;
report any difference between the preview and the PR.

Compare against the merge base with the PR's base branch, or the current
branch's upstream PR base or repository default branch. Inspect story exports
inside changed story files, including shared mocks, decorators, and args.
Include existing stories whose rendered behavior changes through those shared
definitions. Distinguish added stories from updated stories, and give a short
reason for each update. A changed assertion alone does not make a story new.

If no stories were added or changed, say so. Removed stories can be reported
separately without preview links. Do not create stories to fill the table.

## Run and open Storybook

Read the owning workspace's instructions, package scripts, and Storybook
configuration. For Ledidi, load `dev-stack` for dependency preparation and
local operation. Storybook with mocked providers needs only its own server;
start backend services only when the stories require them.

Use the workspace's Storybook package script. Reuse a running server only
after confirming it serves the selected checkout. Otherwise start a persistent
server on a free port through the script's supported option or environment
variable. Leave the server running for the user.

Read the running server's `/index.json` to resolve story IDs, display names,
and import paths. Match stories by `importPath` and export name: the ID derives
from the story title and may not contain the source filename. Build links as
`http://localhost:<port>/?path=/story/<id>` using the returned IDs.

Use the available browser automation to open each added or changed story in
a tab. Verify that each preview renders its intended state; a loaded Storybook
sidebar alone is insufficient. Error-state stories should show the component's
error message, not a Storybook loading or compilation error. Keep the tabs open
using the browser tool's deliverable mechanism when available. If a harness
has no browser automation, use its supported URL opener and state that visual
verification was unavailable.

## Handoff

Lead with the local Storybook URL and the branch or PR being served. Return
a Markdown table with `Story` and `Change` columns, one row per added or
changed story. Make each story name a direct local link. Use `Added` for new
stories and a short description such as `Updated error message` for changes.
Include the component name when story names would otherwise be ambiguous.

State that Storybook and the tabs remain open. Report any preview that failed
to render, and any local changes that make the preview differ from the PR.
