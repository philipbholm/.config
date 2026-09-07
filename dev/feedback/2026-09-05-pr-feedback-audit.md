# Ledidi PR feedback audit — 5 September 2026

The agent context now covers the reusable corrections found across Philip's
149 Ledidi pull requests. The context also resolves conflicting service and
workflow instructions and makes nested guidance reachable by Claude Code,
Codex, and Cursor.

## Coverage

| Source | Records |
| --- | ---: |
| Inline comments, including replies | 1,804 |
| PR conversation comments | 139 |
| Reviews, including empty approvals | 1,234 |
| Total | 3,177 |
| Records containing written feedback | 2,105 |

The collection used the authenticated GitHub API, paginated through all 3,652
repository PRs, and selected all 149 authored by `philipbholm`, across every
state. Those PRs span 13 October 2024 through 4 September 2026. Each selected
PR's inline comments, issue comments, and reviews were fetched with pagination.
Every available body was read, including replies, duplicate findings, automated
summaries, and comments on superseded branches. Empty reviews were recorded.

The [per-comment assessment](2026-09-05-pr-feedback-assessment.json) includes the
PR inventory, source links, authors, comment IDs, reply relationships, body
hashes, individual decisions, and reasons. Its record keys exactly match the
source collection, with no missing or duplicate records. The assessments
describe whether a lesson belongs in instructions; they are not claims that
every historical PR's current code was reverified.

Deleted or inaccessible comments cannot be recovered from the API.
[PR4069's review](https://github.com/ledidi-as/ledidi-monorepo/pull/4069)
announces fourteen original findings, but only six original inline findings
remain available. The assessment records the available summary and replies.
External review systems linked from comments were not treated as additional
GitHub comment bodies.

## Where the corrections live

The [coding-standards skill](../../skills.work/coding-standards/SKILL.md) remains
the engineering authority. Existing rules were strengthened where a broad
instruction had repeatedly failed to prevent a concrete mistake. Specialized
rules load only when their topic applies.

| Context | Corrections and representative evidence |
| --- | --- |
| [TypeScript](../../skills.work/coding-standards/references/typescript.md) | Domain validation in use cases, actual runtime parsing, omitted versus invalid values, and update semantics. [Locale fallback](https://github.com/ledidi-as/ledidi-monorepo/pull/2189#discussion_r3115981227), [domain parsing](https://github.com/ledidi-as/ledidi-monorepo/pull/2189#discussion_r3085448360). |
| [Backend](../../skills.work/coding-standards/references/backend.md) | Service-specific use-case patterns, real response fields, relationship ownership, replay invariants, and precise database error mapping. [Placeholder fields](https://github.com/ledidi-as/ledidi-monorepo/pull/1596#discussion_r2751305205), [repeatability](https://github.com/ledidi-as/ledidi-monorepo/pull/3007#discussion_r3419424927), [not-found mapping](https://github.com/ledidi-as/ledidi-monorepo/pull/4292#discussion_r3893875113). |
| [Frontend](../../skills.work/coding-standards/references/frontend.md) | Query identity, live errors, per-record saves and retries, route maps, complete boolean feature guards, usable confirmations, and meaningful stories. [Repeated stale-data defect](https://github.com/ledidi-as/ledidi-monorepo/pull/4342#discussion_r3913335707), [route maps](https://github.com/ledidi-as/ledidi-monorepo/pull/2189#discussion_r3084616942), [clinical deletion](https://github.com/ledidi-as/ledidi-monorepo/pull/3294#discussion_r3666898104). |
| [Testing](../../skills.work/coding-standards/references/testing.md) | Real authorization boundaries, isolated grants, nonempty exclusion fixtures, non-default controls, persisted event assertions, shared setup ownership, and preservation of user flows. [Wired authorization](https://github.com/ledidi-as/ledidi-monorepo/pull/4185#discussion_r3880797280), [control transitions](https://github.com/ledidi-as/ledidi-monorepo/pull/4335#discussion_r3915312742), [restored flow](https://github.com/ledidi-as/ledidi-monorepo/pull/3247#discussion_r3434177013). |
| [Security](../../skills.work/coding-standards/references/security-and-privacy.md) | Parent/tenant checks, raw-query scope, independent permissions, and an explicit domain audit boundary. [Parent ownership](https://github.com/ledidi-as/ledidi-monorepo/pull/4185#discussion_r3880797178), [independent grants](https://github.com/ledidi-as/ledidi-monorepo/pull/3708#discussion_r3712566067). |
| [Reliability](../../skills.work/coding-standards/references/correctness-and-reliability.md) | Semantic defaults and ordering, bounded batches, effective transactions, migration recovery and upgrade paths, and terminal stream events. [Default role](https://github.com/ledidi-as/ledidi-monorepo/pull/4069#discussion_r3775162323), [migration order](https://github.com/ledidi-as/ledidi-monorepo/pull/1549#discussion_r2727811375), [stream completion](https://github.com/ledidi-as/ledidi-monorepo/pull/2215#discussion_r3168634543). |
| [Infrastructure](../../skills.work/coding-standards/references/infrastructure.md) | Shared build inputs through every CI gate, runtime dependencies, startup validation, seed cleanup, and background-job failure propagation. [CI gates](https://github.com/ledidi-as/ledidi-monorepo/pull/3722#discussion_r3663997859), [background jobs](https://github.com/ledidi-as/ledidi-monorepo/pull/1765#discussion_r2837408937). |
| [Registry analytics](../../skills.work/coding-standards/references/registry-analytics.md) | Save/run compatibility, complete variant wiring, observation units, missing versus zero, finite results, work limits, and configured suppression. [Save validation](https://github.com/ledidi-as/ledidi-monorepo/pull/4335#discussion_r3911294186), [finite results](https://github.com/ledidi-as/ledidi-monorepo/pull/4335#discussion_r3915312696), [bounded work](https://github.com/ledidi-as/ledidi-monorepo/pull/3707#discussion_r3719539938). |
| [Agent tools](../../skills.work/coding-standards/references/agent-tools.md) | Executable prompt contracts in both locales, authorization, code-enforced limits, preview gates, and exact message history. [Invalid examples](https://github.com/ledidi-as/ledidi-monorepo/pull/3477#discussion_r3614172523), [duplicated history](https://github.com/ledidi-as/ledidi-monorepo/pull/3708#discussion_r3712069058). |
| [PR writing](../../skills/write-pr/references/work.md) | Claims, migration names, API changes, and verification match the final implementation. Risk facts fit the current body format. [Stale description](https://github.com/ledidi-as/ledidi-monorepo/pull/3007#discussion_r3395051243). |

## Suggestions that did not become blanket rules

Full threads changed several conclusions. Reviewers accepted useful fixture
helpers, reconsidered projection getter splitting, and kept distinct tests
even when their assertions overlap. The instructions preserve those choices.
They do not mandate a Polars rewrite, one file per projection, arbitrary file
length limits, a ban on all effects, or direct Prisma reads for every assertion.

Clinical deletion protection follows the actual data removed, including the
human decision to retain stronger confirmation. A supported minimum group
size of zero was not silently replaced with a guessed floor. The aggregate
read-audit boundary remains a domain policy question; this work does not invent
a per-card audit requirement. Disposable pre-production formats are distinct
from deployed clinical data and event history.

Automated warnings without a demonstrated trust boundary were not promoted
into universal bans on computed filesystem paths, regexes, or object indexing.
Local preference comments and deferred product choices remain evidence in the
assessment rather than commands for unrelated future work.

## Holistic context review

The [root template](../context/ledidi-monorepo/AGENTS.md) now requires agents to
read both nested instruction filenames and their applicable references before
editing or reviewing. It includes affected consumers in compatibility work and
distinguishes the Trials product from study domain objects.

[Context precedence](../context/ledidi-monorepo/context-precedence.md) resolves
legacy setup commands, fixed ports, GitHub issue-tracker instructions, test
review conventions, and known missing local references. The useful form-element,
Storybook, and service-domain guidance still applies. Tracked instructions in
the monorepo were not changed by this dotfiles update.

[Verification](../../skills.work/verify-change/SKILL.md) and
[stack setup](../../skills.work/dev-stack/SKILL.md) now use the PR's actual base
for stacked changes and retain domain-required E2E coverage. Registries builder
and projection conventions no longer override studies or admin architecture.

An independent review exercised four scenarios against the updated documents:
a studies use case, a new registries analysis family, a frontend entity-switch
bug, and checks after rebasing a stacked PR. Its final corrections were applied.

The existing untracked `dev/context/coding-standards/` directory and
`skills.work/address-feedback/references/github-feedback.md` were preserved.
They have no active routing from the edited context and were not made a second
source of policy. Historical feedback archives remain evidence, not instructions.

## Verification

- All 3,177 source records have exactly one assessment entry.
- The updated root template was rendered into all 16 checkouts. Each checkout's
  `AGENTS.md` and `CLAUDE.local.md` agree apart from the filename heading, with
  no unresolved port placeholders.
- All 15 linked worktrees match the renderer using their saved stack metadata.
  The main checkout's live stack-state check could not run because Docker was
  unavailable; no Docker services were started for this documentation change.
- Local Markdown links and the shared Claude/Codex/Cursor skill links resolve.
- Changed skills pass the skill validator, and `git diff --check` passes.

These instructions reduce recurrence and require checks against the final diff.
They cannot guarantee that an agent will never miss valid feedback again.
