---
name: review-pr
description: Review a GitHub pull request through isolated Coding Standards, Security and Privacy, and Correctness and Reliability passes. Produces an HTML report by default and posts only when explicitly requested. Use only for a PR number; use code-review for local branches and fixed-point diffs.
argument-hint: "[pr number] [report|post]"
---

# Review a pull request

Use the supplied PR number; ask if it is missing. Default to read-only
`report` mode. Use `post` only when the user explicitly asks to publish findings.

Read [Review quality](/Users/philip/.config/skills/code-review/references/review-quality.md).
It owns the finding criteria, evidence requirements, severity definitions,
and coordination of isolated passes.

## Pin the review

Fetch the PR repository, number, URL, title, body, author, changed files, and
base and head SHAs. Confirm both SHAs resolve locally, fetching the PR ref if
needed. Capture one three-dot comparison and its commit list using those SHAs.

Stop if the PR cannot be resolved; report no changes when the diff is empty.
Read the repository's `AGENTS.md` or `CLAUDE.local.md`, when present, and load
`coding-standards`. Do not load
`/Users/philip/.config/dev/feedback/SYNTHESIZED_LEARNINGS.md`.

## Run the isolated passes

Each pass requires its own subagent. Spawn all three in parallel. If the
harness cannot provide three isolated subagents, stop and report that the
review contract cannot be met.

Give each reviewer the PR metadata and description, pinned comparison,
commit list, Review quality reference, `coding-standards` skill path, and
references for its assigned pass:

| Pass | Sources |
|------|---------|
| Coding Standards | Relevant language, backend, frontend, testing, and infrastructure references; `write-pr` for PR text and `write-commit` when assessing commit messages |
| Security and Privacy | Security and testing references |
| Correctness and Reliability | Correctness and testing references |

Each pass applies the standards baseline and expands its references when the
evidence requires it. Tell each reviewer: "Perform only your assigned pass.
Do not invoke review-pr or spawn other agents."

## Verify and deliver

Verify candidates under Review quality. Merge duplicate findings across
passes while retaining their pass labels. Rank findings by severity without
a count limit.

Read [Review delivery](references/delivery.md) and deliver in the selected mode.
