---
name: setup-matt-pocock-skills
description: "Configure this repo for the vendored engineering skills: set up its local issue tracker, triage label vocabulary, and domain doc layout. Run once before first use of the tracker-backed skills."
disable-model-invocation: true
---

# Setup Matt Pocock's Skills

Create the private per-repo configuration used by the engineering skills on this machine:

- **Issue tracker**: GitHub, GitLab, local markdown, or another workflow
- **Triage labels**: the strings used for the five canonical triage roles
- **Domain docs**: where `CONTEXT.md` and ADRs live, and how skills consume them

Configuration lives under `.scratch/agents/`. The global agent instructions point every harness there, so this skill does not edit the repo's `AGENTS.md` or `CLAUDE.md`.

This is a prompt-driven skill. Explore, present what you found, confirm with the user, then write.

## Explore

Read the current state before proposing changes:

- `git remote -v` and `.git/config`
- `.gitignore` and `git check-ignore .scratch/agents/issue-tracker.md`
- `.scratch/agents/` and any existing `.scratch/` efforts
- `CONTEXT.md`, `CONTEXT-MAP.md`, `docs/adr/`, and any `src/*/docs/adr/`
- Whether the `triage` skill is installed
- Monorepo signals: `pnpm-workspace.yaml`, a `workspaces` field in `package.json`, or populated `packages/*` directories with their own `src/`

If `.scratch/` does not exist, say so before proposing its creation. The directory must be ignored before configuration is written there.

## Confirm the configuration

Present what exists and what is missing. Then confirm each choice that remains open.

### Issue tracker

Recommend the tracker the repo already uses. Offer:

- **GitHub**: GitHub Issues through `gh`
- **GitLab**: GitLab Issues through `glab`
- **Local markdown**: files under `.scratch/<effort>/`
- **Other**: the user's workflow, recorded as prose

Write the chosen workflow to `.scratch/agents/issue-tracker.md`. GitHub and GitLab templates keep pull or merge requests out of triage by default.

### Triage labels

When `triage` is installed, recommend the default roles: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`. Write the accepted mapping to `.scratch/agents/triage-labels.md`.

Skip this choice and file when `triage` is unavailable.

### Domain docs

Use a single-context layout by default: root `CONTEXT.md` and `docs/adr/`. When exploration found a large monorepo, offer a root `CONTEXT-MAP.md` that points to per-context `CONTEXT.md` and ADR directories.

Write the consumer rules and selected layout to `.scratch/agents/domain.md`. The domain files themselves are created lazily by `domain-modeling`.

## Write

Show drafts of every file before writing. Let the user edit them.

After approval:

1. Ensure `.scratch` is ignored. Add it to the repo's root `.gitignore` when no existing ignore rule covers it.
2. Create `.scratch/agents/`.
3. Write `issue-tracker.md`, `domain.md`, and, when applicable, `triage-labels.md` from the templates in this skill folder.
4. Run `git check-ignore .scratch/agents/issue-tracker.md`. The setup is incomplete until this command confirms the configuration is ignored.

For another issue tracker, write `issue-tracker.md` from the user's description.

Tell the user which files were created and which engineering skills consume them. Re-run this skill when switching trackers or changing the domain layout.
