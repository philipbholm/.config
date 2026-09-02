# Upstream contract for `setup-matt-pocock-skills`

Checked against `mattpocock/skills` commit [`6654f6b60cd9d5be8b54c6fafe44346dabeb3b76`](https://github.com/mattpocock/skills/tree/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76) on 2026-09-02.

## Outcome

Upstream separates two jobs:

1. **Install or expose the skill files to an agent harness.** Claude Code's supported route is the managed plugin. Codex and other agents use `skills.sh`, which copies selected skills into a project. The repository also contains a global symlink helper, but upstream marks that helper as maintainer-only and unsupported.
2. **Configure each repository that consumes the engineering skills.** `/setup-matt-pocock-skills` must run once in every repository. The setup output is committed, repository-local markdown under `docs/agents/` plus an `## Agent skills` pointer block in the instruction file that the harness reads. Upstream explicitly says there is no global setup mode.

A machine-wide vendored copy can therefore expose the same skill implementation to many repositories, but the vendored copy does not replace the per-repository `docs/agents/` setup. Upstream does not document Cursor by name or define a Cursor-specific install path.

## Upstream requirements checklist

### Skill distribution

- [ ] Pick one distribution route. Do not install both the Claude Code plugin and editable file copies, because that produces duplicate skills. [README, lines 25-27](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/README.md#L25-L27)
- [ ] For Claude Code's supported route, install `mattpocock-skills` from the official marketplace. The plugin is a managed, read-only bundle and receives marketplace updates. [README, lines 31-44](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/README.md#L31-L44)
- [ ] For Codex and other agents, run `npx skills@latest add mattpocock/skills`, select the desired skills and target agents, and include `setup-matt-pocock-skills`. [README, lines 48-57](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/README.md#L48-L57)
- [ ] Treat `skills.sh` copies as editable files owned by the consumer. They do not update automatically; `npx skills update` pulls upstream changes. [README, lines 61-70](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/README.md#L61-L70)
- [ ] Preserve each skill directory, not only `SKILL.md`. Codex behavior also comes from the adjacent `agents/openai.yaml`: the file carries picker metadata and, for user-invoked skills, `policy.allow_implicit_invocation: false`. [Invocation contract, lines 3-10](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/.agents/invocation.md#L3-L10)

### Per-repository setup

- [ ] Run `/setup-matt-pocock-skills` once in every repository before the other engineering skills. The skill is user-invoked and cannot run implicitly. [Setup skill, lines 1-15](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L1-L15)
- [ ] Let the setup inspect the repository before deciding anything: remotes, root instruction files, existing domain docs and ADRs, prior `docs/agents/` output, `.scratch/`, installed `triage`, and monorepo signals. [Setup skill, lines 19-30](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L19-L30)
- [ ] Configure the issue tracker in `docs/agents/issue-tracker.md`. GitHub, GitLab, local markdown, and a user-described tracker are supported. GitHub and GitLab default `PRs as a request surface` to off. [Setup skill, lines 38-49](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L38-L49)
- [ ] If `triage` is installed, write `docs/agents/triage-labels.md`. The default role-to-label mapping is `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. [Setup skill, lines 51-57](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L51-L57)
- [ ] Record a single-context domain layout by default: root `CONTEXT.md` and `docs/adr/`. Offer `CONTEXT-MAP.md` only when the repository has monorepo signals. [Setup skill, lines 59-61](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L59-L61)
- [ ] Show the proposed instruction block and `docs/agents/*.md` contents before writing them. [Setup skill, lines 63-70](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L63-L70)
- [ ] Add or update one `## Agent skills` block. The upstream selection rule is `CLAUDE.md` first, otherwise `AGENTS.md`; if neither exists, ask which one to create. Do not create the second file or duplicate the block. [Setup skill, lines 72-82](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L72-L82)
- [ ] Make the block point to `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and, when `triage` is installed, `docs/agents/triage-labels.md`. [Setup skill, lines 84-110](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L84-L110)
- [ ] Keep setup output repository-local. Upstream says the output is committed markdown and that no user-level or global configuration mode exists. [Human-facing setup docs, lines 15-26](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/docs/engineering/setup-matt-pocock-skills.md#L15-L26)
- [ ] Confirm that the instruction block is in the file the active harness actually reads. This is the acceptance criterion even though the setup skill's `CLAUDE.md`-first rule can violate it in a mixed-harness repository. [Human-facing setup docs, lines 84-90](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/docs/engineering/setup-matt-pocock-skills.md#L84-L90)

## Harness exposure

| Harness | Explicit upstream route | Expected exposure |
| --- | --- | --- |
| Claude Code | Official `mattpocock-skills` plugin | The plugin manifest explicitly lists every promoted engineering and productivity skill, including `setup-matt-pocock-skills`. [Plugin manifest, lines 21-47](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/.claude-plugin/plugin.json#L21-L47) |
| Codex | `npx skills@latest add mattpocock/skills` | Selected skill directories must include `agents/openai.yaml`. A native Codex plugin is deferred; `skills.sh` is the supported current path. [Codex plugin ADR, lines 19-23](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/.agents/adr/0002-ship-as-a-claude-code-plugin.md#L19-L23) |
| Other Agent Skills-compatible harnesses | `npx skills@latest add mattpocock/skills` | Upstream calls `skills.sh` the universal installer, but leaves destination selection to that installer. [Install contract, lines 25-37](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/.agents/install-block.md#L25-L37) |
| Cursor | No Cursor-specific route is named in this repository's install contract | Upstream provides no basis for claiming that a particular Cursor directory, symlink, or discovery mechanism is supported. Cursor exposure must be verified against Cursor itself or against the generated installer output; that verification is outside this primary-source-only upstream review. |

Upstream's own development helper links every non-deprecated skill into `~/.claude/skills` and `~/.agents/skills`. It identifies the first as Claude Code and the second as Codex plus other Agent Skills-compatible harnesses. The script explicitly says it is maintainer-only and **not a supported installer**. [Link helper, lines 1-25](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/scripts/link-skills.sh#L1-L25)

That helper is broader than the Claude plugin: it excludes only `deprecated`, while the plugin ships only the promoted `engineering` and `productivity` buckets. Upstream's repository instructions define `misc` and `in-progress` as non-promoted and exclude them from the plugin. [Repository instructions, lines 1-11](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/CLAUDE.md#L1-L11)

## Expected behavior and known upstream gaps

- Setup configures tracker instructions, a label mapping, and domain-doc layout. Setup must not edit any vendored `SKILL.md`. [Human-facing setup docs, lines 84-90](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/docs/engineering/setup-matt-pocock-skills.md#L84-L90)
- Setup does not create labels in GitHub or another tracker. `triage-labels.md` only maps canonical roles to label strings, so mapped labels must already exist. [Human-facing setup docs, lines 65-70](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/docs/engineering/setup-matt-pocock-skills.md#L65-L70)
- The instruction-file rule has a documented mixed-harness bug. If both files exist, setup writes to `CLAUDE.md` even when Codex is active. Upstream's acceptance criterion is stricter: the block must appear in the instruction file that the harness reads. [Human-facing setup docs, lines 61-63](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/docs/engineering/setup-matt-pocock-skills.md#L61-L63)
- The setup skill's closing instruction says re-run only to switch trackers or restart. The human-facing docs record conflicting advice after releases because seed templates can change. Treat re-running after a significant upstream update as a compatibility check, not as a clear normative requirement. [Setup skill, lines 114-116](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/skills/engineering/setup-matt-pocock-skills/SKILL.md#L114-L116), [human-facing docs, lines 57-59](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/docs/engineering/setup-matt-pocock-skills.md#L57-L59)

## Initial comparison with this machine

The machine-wide exposure is correct for the three local harnesses:

| Harness | Local destination | Result |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/<name>` | Correct. Claude documents `~/.claude/skills` as the personal scope for all projects. [Claude Code skills](https://code.claude.com/docs/en/skills#where-skills-live) |
| Codex | `~/.agents/skills/<name>` | Correct. Official OpenAI documentation names `$HOME/.agents/skills` as user scope, and says Codex follows symlinked skill folders. [OpenAI Docs](https://learn.chatgpt.com/docs/build-skills#where-codex-loads-local-skills) |
| Cursor | `~/.agents/skills/<name>` | Correct for local agents. Cursor documents `~/.agents/skills` as user-level scope. Cursor does not copy these skills to Cloud Agents or remote workers. [Cursor skills](https://cursor.com/docs/skills#skill-directories) |

`install-common.sh` links every `skills/*` entry into both destinations, and `install-work.sh` adds `skills.work/*`. A live audit on 2026-09-02 found the same 22 links in both destinations and no broken links.

The Matt Pocock engineering-flow setup is not complete:

- `skills/setup-matt-pocock-skills/` is absent, so its explicit command does not resolve in any of the three harnesses.
- The global rule in `agents/AGENTS.md` points to `.scratch/agents/issue-tracker.md` and `.scratch/agents/triage-labels.md`. Upstream consumers are configured through repository-local `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and `docs/agents/triage-labels.md` plus an instruction-file block.
- Only `~/work/ledidi-monorepo` had `.scratch/agents/issue-tracker.md` during the live audit. No inspected work repo had `docs/agents/issue-tracker.md`.
- The local convention can work as a deliberate fork because the global instruction tells agents to read `.scratch/agents/*`. The local convention is not the setup produced by the linked upstream skill, and it omits upstream's `docs/agents/domain.md` consumer rules.

Therefore: **distribution is set up correctly; upstream per-repository setup is not.** Either vendor the complete `setup-matt-pocock-skills` directory and adopt its `docs/agents/*` output, or keep the `.scratch/agents/*` fork and vendor a renamed/customized setup skill whose output matches that fork.

## Resolution

The local fork was completed on 2026-09-02:

- `setup-matt-pocock-skills` is vendored with tracker, triage-label and domain templates that write to `.scratch/agents/`.
- The global agent instructions point tracker-backed skills and code review to the configured tracker, and point engineering exploration to `.scratch/agents/domain.md`.
- `code-review` no longer hardcodes `docs/agents/issue-tracker.md`.
- The setup skill is linked into both `~/.claude/skills` and `~/.agents/skills`.
- `ledidi-monorepo` has an ignored `.scratch/agents/domain.md`.

The result remains a deliberate local fork from upstream's committed `docs/agents/*` contract.

## Explicit requirements versus inference

### Explicit upstream requirements

- Skill installation and repository setup are separate.
- Repository setup is per repo; there is no global setup configuration.
- `setup-matt-pocock-skills` is user-invoked and must be available in each target harness.
- Codex needs the whole skill directory, including `agents/openai.yaml`, for the upstream invocation policy and UI metadata.
- The repository must contain `docs/agents/issue-tracker.md`, `docs/agents/domain.md`, and conditionally `docs/agents/triage-labels.md`.
- The harness-readable instruction file must point to those files.

### Inference for a vendored, machine-wide installation

- A single vendored source tree with per-harness symlinks can keep the skill implementations identical across repositories. Upstream uses this pattern for its own development environment, but does not support the helper as an end-user installer.
- If both Claude Code and Codex must consume the same repository-local setup block, one canonical instruction file plus a harness-specific pointer or symlink can avoid divergence. Upstream documents this as a workaround, not as the setup skill's native behavior. [Human-facing setup docs, lines 61-63](https://github.com/mattpocock/skills/blob/6654f6b60cd9d5be8b54c6fafe44346dabeb3b76/docs/engineering/setup-matt-pocock-skills.md#L61-L63)
- A Cursor exposure path cannot be validated from `mattpocock/skills` alone. The upstream repository neither names Cursor in its installation contract nor defines a Cursor skill directory.
- A global instruction that teaches all repositories where local tracker configuration lives does not satisfy the upstream contract by itself. The downstream skills expect repository-local `docs/agents/*.md`; a global rule can only add a convention around those files.

## Confidence

High for the upstream contract at the pinned commit. Medium for how a vendored installation should map to Cursor, because upstream provides no Cursor-specific evidence.
