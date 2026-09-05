---
name: verify-change
description: Scope Ledidi checks and handle failures before verification, commits, or pushes, including hook failures after a rebase.
---

# Verify a Ledidi change

Follow the repository context's service-setup safeguard. This skill governs
check scope and push gates; `dev-stack` owns setup commands.

Before running checks or investigating a hook failure, identify the required
workspaces from `git diff --name-only origin/master...HEAD` and their affected
dependencies and consumers. Hook path filters do not cover every dependency;
inspect schema and generation inputs before excluding a consumer with no
direct file changes. Run required checks even when the hook does not select
them. A hook selecting a workspace is not itself a reason to prepare it.

Include staged, unstaged, and relevant untracked files when verifying
uncommitted work.

A "full suite" means the full suites for those workspaces, not the whole
monorepo. Run E2E when the user asks for it or browser verification requires
it; "red/green TDD" requires unit and relevant E2E tests.

When verification needs setup, load `dev-stack` and prepare only the required
workspaces and services. For checks that consume generated types, follow the
preparation steps in `dev-stack` before running them.

Classify failures from evidence, not from whether master is green:

| Cause | Action |
|-------|--------|
| The branch caused the failure | Fix it and rerun the required checks. |
| Required setup is missing | Prepare only what the branch's verification needs, then rerun. |
| A history rewrite made a hook select an unrelated workspace | Apply the narrow pre-push exception below. |
| Another pre-existing failure, or an unexplained failure | Report the failing command and evidence. Ask before expanding the task; do not bypass the failure. |

Pre-commit hooks must pass; do not bypass them. Before pushing, required
branch checks and pre-push hooks must pass, with this single exception:

After a rebase or another history rewrite, Lefthook can select a workspace
changed only by incoming base-branch commits. Confirm that the workspace is
absent from `git diff --name-only origin/master...HEAD` and is not an affected
dependency or consumer of the branch's changes. If that workspace is the only
reason pre-push fails and the branch's required checks passed, use
`git push --force-with-lease --no-verify` instead of preparing and checking that
workspace locally. The pull request checks cover the incoming changes.
