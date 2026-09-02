---
name: review-pr
description: Review a GitHub pull request through isolated Coding Standards, Security and Privacy, and Correctness and Reliability passes. Produces an HTML report by default and posts only when explicitly requested. Use only for a PR number; use code-review for local branches and fixed-point diffs.
argument-hint: "[pr number] [report|post]"
---

Review one GitHub pull request. The default `report` mode is read-only. Use
`post` mode only when the user explicitly asks to publish the findings.

This review has three required, isolated passes:

1. **Coding Standards** — compliance with the documented work standards and
   repository-specific additions.
2. **Security and Privacy** — authorization, isolation, sensitive-data flows,
   auditability, and abuse paths.
3. **Correctness and Reliability** — wrong results, corrupt or inconsistent
   data, unsafe failures, concurrency, compatibility, and missing tests for
   those risks.

Each pass requires its own subagent. If the current harness cannot create three
isolated subagents, stop and report that the review contract cannot be met.

## Pin the review

Use the supplied PR number. Ask for one when it is missing. Do not use
this skill for a local branch or an arbitrary diff.

Default to `report` mode. Use `post` mode only when the user passes `post` as
an argument or asks in plain words to publish the findings to GitHub.

Fetch the PR metadata, including its repository, number, URL, title, body,
author, files, base SHA, and head SHA. Confirm both SHAs resolve locally,
fetching the PR ref when needed. Define one three-dot comparison against those
exact SHAs and use it throughout the review. Also capture the commits in that
range.

Fail here when the PR cannot be resolved or the pinned diff is empty.

Read:

- `/Users/philip/.config/dev/context/CODING_STANDARDS.md`
- the repository's `AGENTS.md` or `CLAUDE.local.md`, when present

The shared standards are authoritative. Repository context may add stricter
rules. Do not load `/Users/philip/.config/dev/feedback/SYNTHESIZED_LEARNINGS.md`.

Read the PR description, the complete pinned diff, and the surrounding code in
every changed area. A diff hunk alone cannot prove that authorization, tests,
callers, or compatibility handling are complete.

## Run the isolated passes

Spawn all three subagents in parallel. Give each subagent:

- the PR metadata, pinned SHAs, diff command, and commit list
- its named pass and only the standards sections relevant to that pass
- permission to inspect the full changed files, callers, tests, migrations,
  schemas, and configuration needed to verify a candidate
- this output contract for every candidate: severity, file and line, evidence,
  consequence, violated rule when applicable, suggested correction, and what
  remains uncertain
- this guard: `Do not invoke review-pr and do not spawn other agents. Perform
  this pass directly.`

The Coding Standards pass applies every relevant documented rule, including PR
title, description, and risk-assessment rules. It skips checks already enforced
by repository tooling.

The Security and Privacy pass traces sensitive data across trust boundaries.
It checks authorization and scope, tenant isolation, frontend and API exposure,
logs and errors, audit logging, data minimization and retention, destructive
operations, configuration, dependencies, and third-party data sharing. It
reports technical risks and makes no claim of legal or regulatory compliance.

The Correctness and Reliability pass checks observable behavior and data
integrity. It follows mutations, migrations, events, projections, imports,
exports, retries, concurrent operations, external calls, and failure paths. It
checks whether tests cover the important behavior and boundaries.

## Verify the candidates

Subagent output is evidence to investigate, not finished findings. Verify every
candidate against the pinned diff, surrounding code, relevant standard, and
tests. Remove guesses, taste, duplicates, and findings already enforced by
tooling.

Use these severities:

- **Critical** — a credible security, privacy, destructive-data, or severe
  availability risk that can cause substantial harm.
- **Major** — a confirmed problem the author should fix before merge.
- **Minor** — a worthwhile improvement that does not need to block the merge.

Merge duplicate candidates into one finding and retain every pass label that
found it. Put plausible risks that cannot be confirmed under **Needs
investigation**, with the missing evidence stated plainly. Include at most ten
Minor findings.

Once every retained finding is verified, read
[`references/delivery.md`](references/delivery.md) and deliver the result in the
selected mode.
