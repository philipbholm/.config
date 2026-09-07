---
name: registry-release
description: Preview built but unreleased registries components, or deploy selected production artifacts. Covers registries-frontend, registries-service, and codelist; preview and guidance requests dispatch nothing.
---

# Release registries components

Use GitHub repository `ledidi-as/ledidi-monorepo`. A preview or “guide me through
it” request is read-only. A deployment request starts with the same preview.
Use the available shell, browser, and question tools in Claude Code, Codex, or
Cursor; this workflow has no harness-specific dependency.

Read [Release artifacts and workflows](references/workflows.md) before resolving
the candidate. Verify the current build and deploy workflows, including local
actions and scripts they call, rather than relying on historical commands.

## Preview

For the named components, or all three when none is named:

1. Resolve remote production tags and their commit SHAs, including peeled SHAs
   for annotated tags. Select the newest numeric suffix for each component and
   verify the corresponding production build and artifact succeeded. A tag alone
   does not establish a usable release. Report no candidate when none qualifies.
2. Resolve the currently deployed artifact from live deployment state when
   accessible. Otherwise inspect successful deployment jobs for that exact
   component, environment, and tag with pagination, and label the result “last
   successful deployment”. Account for rollbacks and newer partial or failed
   runs; the last successful run may not describe what is live now. If the
   baseline remains unknown, say so and leave the pending-change comparison open.
3. Compare the deployed and candidate commits. Show component-relevant changes,
   including shared dependencies and build inputs. A monorepo comparison also
   contains commits this component does not ship. Identify schema or deployment
   dependencies that determine release order.

Show one row per component: deployed artifact and evidence, candidate tag and
SHA, relevant changes, workflow, and production target. Equal artifacts mean
there is nothing to release for that component. End here for preview requests.

## Deploy selected artifacts

Use already-named components; ask which components only when the request leaves
the selection open. Before dispatch, obtain confirmation for the concrete tags,
SHAs, production targets, and order from the preview unless the conversation
already approved those exact artifacts. A newer tag does not replace an approved
candidate. Recheck that each approved tag still resolves to the recorded SHA and
the artifact remains available.

Dispatch the verified workflow with `gh workflow run <workflow> --repo
ledidi-as/ledidi-monorepo --ref <tag>`. Record the dispatch time and existing run
IDs first. Identify the new run using workflow, workflow_dispatch event, tag,
head SHA, actor, and dispatch time. If concurrent dispatches leave several
matches, resolve which run is ours before claiming a result. Selecting the
latest run with `-L 1` is insufficient, especially for the shared deploy.yml.

Watch the identified run and relevant deployment job through completion. Respect
environment approvals and actor checks. A queued run or compatibility gate is
pending, not success. Report the exact approval needed when an external actor
must unblock it. On failure, read the logs and determine whether a retry is
justified; do not repeatedly dispatch the same failing deployment. Editing
workflows, moving tags, changing production configuration, or rolling back
requires separate authorization.

Verify the resulting live version or service state when accessible. Otherwise
report workflow success with live verification unavailable. Give the component,
tag, SHA, result, and exact run URL. Report partial success explicitly and keep
dependent components waiting when their prerequisite deployment failed.
