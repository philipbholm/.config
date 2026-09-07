---
name: code-review
description: Review a branch or fixed-point diff through isolated Standards and Spec passes. Report both results separately.
---

# Review a fixed-point diff

Read [Review quality](references/review-quality.md) before reviewing. This
workflow is read-only and uses two parallel, isolated subagents:

- **Standards** checks the repository's documented coding standards.
- **Spec** checks the originating requirements.

## Pin the comparison

Use the fixed point supplied by the user: a commit, branch, tag, or merge-base.
Ask when none is supplied. Resolve it and HEAD to commit SHAs, then capture
one three-dot diff command and the commit list for that comparison. Stop if
the fixed point is invalid; report no changes when the diff is empty.

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
paths, and Review quality reference.

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
