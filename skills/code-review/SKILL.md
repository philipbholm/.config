---
name: code-review
description: Review a branch or task-owned working-tree changes against a fixed base through isolated Standards and Spec passes. Report both results separately.
---

# Review a fixed-point diff

Read [Review quality](references/review-quality.md) before reviewing. This
workflow leaves source files, the real index, and branch refs unchanged. It may
create temporary snapshot artifacts and uses two parallel, isolated subagents:

- **Standards** checks the repository's documented coding standards.
- **Spec** checks the originating requirements.

## Pin the comparison

Use the fixed point supplied by the user or the task/PR base established by
the calling workflow: a commit, branch, tag, or merge-base. Ask only when no
comparison base is known. Resolve the base and HEAD to commit SHAs and pin
their merge-base and committed feature range. Stop if the fixed point is invalid.

For a committed-only review, pin HEAD's tree. For an implementation review,
include task-owned staged, unstaged, and untracked changes by following
[Working-tree snapshots](references/working-tree-snapshots.md). The working-tree
version is the final file when staged and unstaged versions differ; honor an
explicit staged-only or committed-only request. Exclude unrelated local work.

Capture one diff command from the pinned merge-base to the reviewed tree,
alongside the commit list and included local paths. Report no changes only
when that complete comparison is empty.

## Identify the sources

Use an explicitly supplied spec first. Otherwise consult the configured agent
tracker and matching repository documents. Commit-message references are
discovery hints, not a reason to override the user's supplied source.

If no spec is found, run the Standards pass, mark the Spec pass as not reviewed,
and ask for a source if the user wants that assessment. A missing tracker does
not require setup before a standards review.

Discover standards through the repository context and documents such as
`CODING_STANDARDS.md` or `CONTRIBUTING.md`. Follow their selective-loading
instructions.

## Run the isolated passes

Spawn both reviewers in parallel when a spec exists; otherwise run only the
Standards reviewer. Give each the pinned diff command, commit list, source
paths, reviewed tree ID, and Review quality reference. Reviewers read changed
files and surrounding tracked code from that tree, using `git show` or an
isolated export, rather than the mutable checkout.

The Standards reviewer checks documented rules and explains the concrete cost
of any proposed design improvement. The Spec reviewer checks missing or
partial requirements, unintended scope expansion, and incorrect behavior.

Tell each reviewer: "Perform only your assigned pass. Do not invoke
code-review or spawn other agents." If the harness cannot provide the required
isolated passes, report that limitation rather than claiming they ran.

## Verify and report

Verify candidates under Review quality. Present separate `## Standards` and
`## Spec` sections, with concise findings and source references. Preserve the
two axes: do not merge or rerank findings across them. Report the count and
worst issue within each axis, and identify any assessment that could not run.
Name the base and reviewed tree. Before handing findings back, check whether
the task-owned implementation still matches the snapshot. If it changed,
report the review as applying to the earlier snapshot; the implementing
workflow must capture the final version and reassess affected findings and
changes before claiming that version was reviewed.
