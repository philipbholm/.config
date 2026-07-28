# Agent Config Overhaul — Implementation Plan

**Date:** 2026-07-27
**Goal:** Vendor the four superpowers skills worth keeping into this repo and recalibrate them for Opus 5; collapse four redundant skill/agent overlaps; make worktrees work natively with Docker stacks as opt-in.

**Decisions taken** (2026-07-27):

- Rewrite depth: **substantial restructure** — strip compliance scaffolding, keep the real content.
- Worktrees: **native-only** — `<repo>/.claude/worktrees/` is the sole location, `gwc`/`gwd` retired, a new `wt-down` script covers teardown. (Revised from an earlier hybrid design that kept `gwc` for existing branches.)
- Worktree cleanup: remove all current `~/work/worktrees/` directories, **keep every branch**; recreate what is still needed natively from its branch.
- Consolidations: merge `fix-feedback` → `fix-pr-feedback`; fold `review-pr` → `code-review`; extract `systematic-debugging` as a fourth skill.
- **Not** doing: reconciling `skills.work/plan` with `writing-plans`. Residual overlap accepted, see Phase 2c.

## Source of the Opus 5 rewrite rules

All rewrite rules below trace to Anthropic's [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5) guide. The four passages that bear on these skills:

1. *"If your prompt contains explicit verification instructions … remove them: instructions like these cause over-verification on Claude Opus 5 … The same applies to legacy harness scaffolding that adds separate verification steps."*
2. *"Do not delegate work you can finish yourself in a handful of tool calls, and do not use subagents to verify or double-check your own work."*
3. *"Avoid instructing re-checks it already performs."*
4. *"Positive examples of the communication style you want tend to be more effective than instructions about what not to do."*

Plus the scope-control paragraph: *"Make routine judgment calls yourself, and check in only when different readings of the request would lead to materially different work."*

---

## Phase 1 — Extract and recalibrate four skills

Source: `~/.claude/plugins/cache/claude-plugins-official/superpowers/6.2.0/skills/`.
Destination: `claude/skills/` (profile-agnostic — both work and personal machines).

The plugin stays installed-but-disabled (`enabledPlugins.superpowers: false` is already set). Do not delete the cache; it is the reference copy.

### Rewrite rules applied to all four

| # | Rule | Rationale |
|---|---|---|
| R1 | Narrow the `description` frontmatter to a genuine trigger condition. No "You MUST use this before any creative work." | The broad descriptions are the actual over-triggering mechanism, independent of body text. |
| R2 | Delete rationalization / excuse / red-flag tables. | Passage 4 — prohibitions underperform positive examples. |
| R3 | Delete verification checklists and "before marking work complete" gates. | Passage 1 — verbatim the named anti-pattern. |
| R4 | Delete self-review sections that re-check work already done. | Passage 3. |
| R5 | Remove `<HARD-GATE>`, all-caps imperatives, "you cannot rationalize your way out of this". | Compliance-forcing register calibrated for models that under-follow; Opus 5 follows literally. |
| R6 | Keep worked good/bad code examples verbatim. | Passage 4 — this is the format the guide endorses. |
| R7 | Remove mandated subagent handoffs and "REQUIRED SUB-SKILL" directives. | Passage 2. |
| R8 | Drop the graphviz/`dot` process diagrams. | They encode the mandatory-sequence framing and cost tokens without adding information the prose lacks. |
| R9 | Drop "Announce at start: …" lines. | The guide's narration advice points the other way: Opus 5 already narrates readily and benefits from tuning *down*. |

### Task 1.1 — `claude/skills/test-driven-development/`

**Files:**
- Create `claude/skills/test-driven-development/SKILL.md` (from 9.0 KB source, target ~4 KB)
- Create `claude/skills/test-driven-development/writing-good-tests.md` (copy 8.3 KB source near-verbatim; apply R2/R5 only)

**Keep:** the red-green-refactor cycle prose; "Verify RED — watch it fail" as the core mechanic (this is substantive method, not scaffolding); both good/bad `retryOperation` examples; the good-tests quality table; the bug-fix worked example; the "When Stuck" problem/solution table.

**Cut:** "Common Rationalizations" (13 rows), "Red Flags — STOP and Start Over" (13 items), "Verification Checklist" (8 checkboxes), "Final Rule" block.

**Soften:** "The Iron Law" / "Write code before the test? Delete it. Start over." → a plain statement of the discipline and why watching the failure matters. Keep the substance, drop the threat.

**Description rewrite:**
`Use when writing a test for new behavior or a bug fix — covers the red-green-refactor cycle and what makes a test honest.`

### Task 1.2 — `claude/skills/writing-plans/`

**Files:** Create `claude/skills/writing-plans/SKILL.md` (from 6.9 KB, target ~4.5 KB)

**Keep verbatim:** "File Structure", "Task Right-Sizing", "Task Structure" including the `Interfaces:` / Consumes / Produces block, "No Placeholders". These are the load-bearing parts and are already written as positive templates.

**Cut:**
- The plan header's `> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended)…` line — this bakes the delegation anti-pattern into every plan document the skill produces (R7).
- The entire "Execution Handoff" section (offers subagent-driven as the recommended default).
- The "Self-Review" section (R4).

**Change:** "Bite-Sized Task Granularity" currently specifies one action per step at 2–5 minutes, with "run the test" as its own step. Relax to task-level granularity carrying one test cycle — matching the guide's note that Opus 5 *"completes full tasks rather than leaving stubs"* and *"performs best when given the complete task specification up front and left to run."* Keep the checkbox syntax for tracking.

**Plan output path:** source defaults to `docs/superpowers/plans/`. Change to `docs/plans/YYYY-MM-DD-<feature>.md` relative to the current project, with an explicit note that project instructions override (`skills.work/plan` writes to the work vault).

### Task 1.3 — `claude/skills/brainstorming/`

**Files:** Create `claude/skills/brainstorming/SKILL.md` (from 10 KB, target ~4 KB)

**Keep:** explore project context first; ask questions one at a time; prefer multiple choice; propose 2–3 approaches with a lead recommendation and reasoning; YAGNI ruthlessly; the "Design for isolation and clarity" section; the "Working in existing codebases" section (explore before proposing, fix what you're touching, don't propose unrelated refactoring); write the validated design to a spec file.

**Cut:**
- `<HARD-GATE>` block (R5).
- "Anti-Pattern: This Is Too Simple To Need A Design" — directly contradicts the guide's scope-control paragraph. Replace with a one-line judgment call: scale the design to the change, and skip the formal cycle for changes where no reading of the request is ambiguous.
- The 9-item "You MUST create a task for each of these items" checklist (R5) → narrative flow instead.
- The `dot` process-flow digraph (R8).
- "The terminal state is invoking writing-plans. Do NOT invoke frontend-design, mcp-builder, or any other implementation skill." (R7) → a plain pointer that writing-plans is the usual next step.
- "Spec Self-Review" section (R4).

**Drop the visual companion entirely.** It is 13 KB of guide plus a 25 KB Node server, 8 KB HTML template, and start/stop scripts — a plugin-cache dependency that would have to be vendored wholesale, and the skill itself calls it "token-intensive". Recorded here as a deliberate omission rather than an oversight.

**Replace the manual question protocol with `AskUserQuestion`** for any question that has discrete options. The skill predates that tool; it supports multi-select and previews natively, which is strictly better than hand-rolled A/B/C/D text options. Keep one-question-per-message for open-ended exploration.

**Description rewrite:**
`Use before building a feature or changing behavior where the requirements are not yet settled — turns an idea into an agreed design. Skip for changes with one obvious reading.`

### Task 1.4 — `claude/skills/systematic-debugging/`

**Files:**
- Create `claude/skills/systematic-debugging/SKILL.md` (from 9.5 KB)
- Copy `root-cause-tracing.md` (5.3 KB), `condition-based-waiting.md` (3.5 KB), `defense-in-depth.md` (3.7 KB), `condition-based-waiting-example.ts` (5.1 KB), `find-polluter.sh` (2.0 KB)

**Do not copy:** `CREATION-LOG.md`, `test-academic.md`, `test-pressure-1.md`, `test-pressure-2.md`, `test-pressure-3.md` — these are skill-authoring and evaluation artifacts, not content.

Read the source during implementation and apply R1–R9. Expect the same rationalization/red-flag structure to be present; the substantive parts are root-cause tracing and condition-based waiting.

### Task 1.5 — Wire up and verify

**No installer change is required.** `link_claude_dir` (`install-common.sh:111-139`) globs `"$src_dir"/*` and symlinks each entry, so new skill directories under `claude/skills/` are picked up automatically. Confirm with:

```bash
./install.sh work
find ~/.claude/skills -maxdepth 1 -type l -exec sh -c 'printf "%s -> %s\n" "$1" "$(readlink "$1")"' _ {} \;
```

Expect symlinks for all four new skills pointing into `$DOTFILES/claude/skills/`.

Then verify each skill loads and that the descriptions no longer over-trigger: start a fresh session, ask a question that should *not* invoke brainstorming ("what does this function do?"), and confirm no skill fires.

---

## Phase 2 — Collapse the overlaps

### Task 2a — Merge `fix-feedback` into `fix-pr-feedback`

**Files:**
- Modify `claude/skills/fix-pr-feedback/SKILL.md` (17 lines → ~70)
- Delete `claude/skills.work/fix-feedback/` (141 lines)

The merged skill lives in `claude/skills/` (profile-agnostic) and accepts either a PR number/URL/branch **or** a pasted list of issues.

**Keep from `fix-pr-feedback`** (the stance is the valuable part):
- Be critical of feedback; read the surrounding code before deciding.
- Split into what to fix vs. what is not relevant.
- Comment on everything judged not-relevant, making the positive argument for why the code is the way it is — do not just assert intent.
- Only resolve threads when the reviewer is not human; when in doubt, leave open.
- Ask about genuinely unclear comments rather than guessing.

**Keep from `fix-feedback`** (the mechanics):
- Guard: refuse to run on `master`/`main`.
- Status table tracking `summary / status / reason / commit` per issue.
- Per-issue loop: understand → decide → minimal fix → tests if behavior changed → typecheck + relevant tests + lint → focused commit, no `--no-verify`.
- `git status --short` clean-tree check between issues.
- Push handling, including capturing pre-push hook output and fixing it (cap at two cycles).
- The honest final summary with Fixed / Disagreed / Not-fixed sections.

**Cut:**
- **One subagent per issue.** Passage 2: *"Do not delegate work you can finish yourself in a handful of tool calls."* Individual review comments are exactly that. Run the loop inline.
- **The Step 3 review subagent.** It reviews commits made moments earlier in the same session — passage 2's *"do not use subagents to verify or double-check your own work"*, verbatim. Delete it and the capped re-review loop with it.
- The `/tmp/claude/${session-id}/pr-feedback-checklist.md` file mechanic — replace with the native task list (`TaskCreate`/`TaskUpdate`), which is what it was working around.
- The "If more than 3 total failures, ask for help" counter — replace with reporting the blockage when it happens.

### Task 2b — Fold `review-pr` into `code-review`

The underlying problem is **two divergent copies of the Ledidi review-rules corpus**: `review-pr/SKILL.md:19-158` (detailed — `registryTestBuilder`, `withPermission`, storybook determinism, `useEffect`, translations, dates, file naming) and `code-review/SKILL.md:62-90` (short — 3-layer pattern, `Ports`, query destructuring, `ROUTE_MAP`). They disagree by omission in both directions.

**Files:**
- Create `claude/skills.work/code-review/references/review-rules.md` — one merged, deduplicated corpus. Reconcile the two lists; where only one has a rule, keep it.
- Modify `claude/skills.work/code-review/SKILL.md` — replace the inline "Project standards to enforce" block with a pointer to the reference file; add the posting mode; switch to real agent types.
- Delete `claude/skills.work/review-pr/` (157 lines).

**Switch to real agent types.** `code-review` currently spawns reviewers with ~35-line inline prompts and never passes `subagent_type`, so it gets generic agents — leaving 665 lines of carefully-written definitions in `claude/agents.work/` (`ledidi-code-reviewer.md` 234, `ledidi-security-auth-reviewer.md` 209, `ledidi-test-reviewer.md` 222) entirely unused. Change Step 5 to:

```
subagent_type: "ledidi-security-auth-reviewer" | "ledidi-code-reviewer" | "ledidi-test-reviewer"
```

passing the diff command, file list, and the path to `references/review-rules.md`. Drop the per-agent `model: "opus"` pins — `settings.json` already sets `subagentModel: "opus"`.

**Retain the three-reviewer fan-out.** This is *not* the subagent anti-pattern: three distinct lenses over a multi-file diff is precisely the case the guide endorses — *"large tasks that are genuinely independent and parallelizable, such as a wide multi-file investigation"* — and they perform primary review rather than double-checking my own work. Also keep `review-pr`'s scaling rule: diffs over 20 files get chunked into ~15-file assignments.

**Add a posting mode.** `code-review pr <n> --post` carries over from `review-pr`:
- Post inline comments on the relevant line where possible, summary otherwise.
- Note on every comment that the review was automated by Claude Code.
- Every comment must carry an actual suggestion — no content-free observations.
- Hunt relentlessly for code that does not need to exist, overengineering, and needless complication.
- After submitting, re-read all posted comments for substance, then `open` the review URL.

Without `--post`, behavior is unchanged: synthesize and write to `/Users/philip/vaults/work/dev/reviews/`. The `allowed-tools` line needs `Bash(gh:*)` retained for posting (already present).

### Task 2c — Residual overlap, deferred by decision

`claude/skills.work/plan` (268 lines) still duplicates much of the extracted `writing-plans`, and `claude/skills.work/implement` (49 lines) overlaps `executing-plans`. Left alone per the decision above. Revisit once the recalibrated `writing-plans` has had some use; the likely end state is `plan` keeping its vault-path and read-only-exploration behavior while delegating document structure to `writing-plans`.

---

## Phase 3 — Native-only worktrees with opt-in Docker stacks

**Revised 2026-07-27.** Supersedes the earlier hybrid design. `<repo>/.claude/worktrees/` becomes the only worktree location; `gwc`/`gwd` are retired; Docker stacks stay opt-in via `dev up`. All current worktrees under `~/work/worktrees/` are removed, **keeping every branch** — the code lives on the branches, and any worktree still needed gets recreated natively from its branch.

**What works unchanged under native.**

- Docker bind mounts (`dev.sh:444-498`) are all `$repo_root/...`, resolved per worktree — a worktree nested inside the repo needs no compose changes.
- `dev_is_worktree_repo` tests `[ -f "$1/.git" ]`, which holds for native worktrees.
- `.claude/worktrees` is already gitignored in the monorepo (`.gitignore:79`).
- Lazy slot allocation via `dev up` is untouched, which is what makes stacks opt-in.
- `setup-stack.sh` resolves its own root via `git rev-parse --show-toplevel` (`:4`), so it runs correctly inside a native worktree with no change.

**What native cannot do.** `EnterWorktree` creates *new* branches only (`worktree.baseRef`: `fresh` = origin/default, `head` = local HEAD). An existing branch needs `git worktree add .claude/worktrees/<name> <branch>` followed by `EnterWorktree path:<path>` — a two-step the tool explicitly supports. `WorktreeCreate`/`WorktreeRemove` hooks are the *outside-a-git-repository* path and will not fire inside the monorepo, so creation cannot be wrapped. Two capabilities are lost outright: per-invocation base ref (`gwc -b develop`) and automatic stack teardown on removal. Task 3.4 replaces the second; the first has no replacement.

### Task 3.1 — Key stack identity on the worktree directory

**File:** `dev/lib/workspace.sh:61-77`

`dev_worktree_raw_key_for_repo` keys on **branch tail** first, so branch-hopping inside a worktree silently changes its stack identity. `dev_slot_file_for_repo` (`:100`) has no fallback while `dev_existing_slot_file_for_repo` (`:165-192`) has three, so `dev up` recovers but `sync-context.sh:42` and `gwd.sh:29` do not. Observed twice in one day: `dashboard-integration` was on `dash/27-fe-golive`, then `dash/5-golive` — each time computing a `.dev-stacks/` path that does not exist.

**Change:** derive the key from the worktree **directory basename**. For `<repo>/.claude/worktrees/<name>` that yields `<name>`. Drop the `$WORKTREE_BASE`-relative branch (`:72-74`) since that base no longer exists. Keep branch tail only as a last-resort fallback for detached HEAD.

**Hard requirement this creates: always pass an explicit `name` to `EnterWorktree`.** Omit it and the harness generates a random name, which then *becomes* the stack ID — producing unpredictable compose project names and orphaned `~/work/.dev-stacks/` entries. This goes in `CLAUDE.local.md` (Task 3.3).

**No migration needed.** Existing `.dev-stacks/` entries are keyed on branch tails from the old layout, and every worktree that owns them is being deleted in Task 3.6. The state is discarded wholesale rather than migrated.

### Task 3.2 — Give stackless worktrees valid context files

**Files:** `dev/sync-context.sh:40-47`; port section of `dev/context/ledidi-monorepo/CLAUDE.local.md` and `AGENTS.md`

`sync-context.sh` only builds a target for worktrees that **have** a slot file (`:43`). A worktree with no stack is skipped, so it keeps the raw template with literal `{{FRONTEND_PORT}}` / `{{POSTGRES_PORT}}` placeholders. This is the actual blocker for stackless worktrees, and it matters more under native since most worktrees will never get a stack.

**Change:** include slotless worktrees as targets with a `no-stack` marker. Rather than substituting misleading ports, replace the body of the self-contained `## Ports (Worktree-Specific)` section (template lines 18–33) with:

> No dev stack is running for this worktree. Run `dev up` to start one, then re-run `sync-context` to populate the port table.

The section is delimited by the next `##` heading, so a marker-delimited range substitution suffices; no template restructuring.

Also exclude `no-stack` targets from the duplicate-slot warning loop (`:53-66`), which assumes every target carries a numeric slot.

### Task 3.3 — Native-only wiring

1. **`claude/settings.json`** — add `"worktree": { "baseRef": "fresh" }`. Greenfield branches should come off `origin/<default>`, not incidental local HEAD.
2. **`dev/sync-context.sh:47`** — scan `$MAIN_REPO/.claude/worktrees` instead of `$WORKTREE_BASE`. The `find … -type f -name .git` detection still works; only the root changes.
3. **`dev/lib/workspace.sh:6-8`** — repoint `dev_worktree_base` at `<repo>/.claude/worktrees`, or remove it and its callers if nothing needs a single global base any more. Audit all callers before choosing.
4. **Retire `gwc`/`gwd`** — delete `dev/gwc.sh` and `dev/gwd.sh`; drop the `gwc`/`gwd` functions and their completions from `zsh/.zshrc.work:7-34`; remove any `~/bin` symlinks created for them in `install-work.sh`.
5. **Document the routing rule** in `dev/context/ledidi-monorepo/CLAUDE.local.md` — this is the single cheapest thing that stops the wrong tool being reached for:
   - New branch → `EnterWorktree` with an **explicit `name`**, then run `setup-stack.sh`.
   - Existing branch → `git worktree add .claude/worktrees/<name> <branch>`, then `EnterWorktree path:<path>`, then `setup-stack.sh`.
   - Never omit the name. Never use a location outside `.claude/worktrees/`.
   - Docker stack is opt-in: run `dev up` only when browser testing is needed.
   - Teardown → `wt-down` (Task 3.4), not `ExitWorktree action:remove`.

Because no hook fires on creation and `SessionStart` does not fire on a mid-session `EnterWorktree`, running `setup-stack.sh` after entering is an explicit step — the agent's job, per the documented rule above. There is no way to automate it.

### Task 3.4 — `wt-down` teardown script

**Files:** create `dev/wt-down.sh`; symlink to `~/bin/wt-down` in `install-work.sh`

`ExitWorktree action:remove` deletes the directory **and the branch**, and knows nothing about Docker. Both are wrong for this workflow: branches must survive, and the stack must be nuked or it orphans containers, volumes, and the slot file. `gwd.sh:32` did the nuke; nothing native does.

Behavior, run from inside the worktree:

1. Verify this is a worktree (`git rev-parse --git-dir` ≠ `--git-common-dir`, and not a submodule).
2. `dev nuke`, then wait for containers to stop.
3. `cd` to the main repo and `git worktree remove <path>`.
4. `git worktree prune`.
5. Re-run `sync-context`.

**It must not delete the branch.** Leave that to an explicit `git branch -d`. Note also that `gwd.sh:37-38` ran `git checkout -- . && git clean -fd` before removal, silently discarding uncommitted work — `wt-down` should instead **refuse** on a dirty tree and say what is dirty.

### Task 3.5 — Verify tooling does not traverse nested worktrees

Moving worktrees inside the repo puts N copies of `node_modules` under the main repo tree. `.gitignore` covers git, not tooling. Before committing to the migration, check and add ignores for:

- `tsconfig.json` `exclude` (repo-wide typecheck)
- ESLint ignores
- Vitest/Jest `testPathIgnorePatterns` / include globs
- `lefthook.yml` (exists at monorepo root) — staged-file globs
- `.dockerignore` / compose build context
- Cursor `files.exclude` and `search.exclude` for indexing

Measure it rather than assume: time a repo-wide typecheck with one populated native worktree present, compare against a clean tree. This is a monorepo-side change, tracked here because it **gates** the migration — if repo-wide tooling degrades badly, the native layout is the wrong call and this decision should be revisited.

### Task 3.6 — Migrate off `~/work/worktrees`

Survey as of 2026-07-27 — seven directories plus one stale `git worktree list` entry:

| Worktree | Branch | Dirty | Unpushed | Note |
|---|---|---|---|---|
| `dashboard-integration` | `dash/5-golive` | — | 0 | drifted branch; stack keyed wrong today |
| `dashboard-poc` | `dashboard-poc` | — | 40 | |
| `demo-ous` | `demo-ous` | **1 file** | no upstream | real work, see below |
| `demo-stolav` | `demo-stolav` | 1 file | 253 | generated-file noise, discard |
| `init-dashboards` | `init-dashboards` | — | 0 | |
| `revert-timeline` | `revert-timeline` | — | 0 | |
| `tmp` | `tmp` | — | no upstream | |
| *(stale)* | detached | — | — | `/private/tmp/claude-501/…/owner-wt`, needs prune |

**Only one item is genuinely at risk:** `demo-ous` has an uncommitted change to `apps/registries-frontend/…/diagnosis-list-compact/diagnosis-list-compact.tsx` (−15/+3). Commit or stash it to `demo-ous` before removing the directory.

`demo-stolav`'s `AGENTS.md` diff is **not** real work — `sync-context` overwrote the committed copy with the newer template, whose text lives at `dev/context/ledidi-monorepo/AGENTS.md:68` in this repo. Safe to discard.

The five stashes live in the common git dir and are unaffected by worktree removal. `demo-ous` and `tmp` have no upstream: their branches survive removal but exist only locally, so push them first if they matter.

**Steps:**

1. Commit the `demo-ous` change to its branch.
2. Per worktree: `cd` in, `dev nuke`, `cd` out, `git worktree remove <path>` — **not** `gwd`, which would discard uncommitted work.
3. `git worktree prune` to clear the stale `/private/tmp` entry.
4. Confirm nothing is orphaned: `docker ps -aq --filter label=com.ledidi.dev-workspace` should be empty; clear leftover `~/work/.dev-stacks/` entries.
5. `rmdir ~/work/worktrees` once empty.
6. Recreate only what is still needed, natively, from its branch (the demo worktrees are the likely candidates).

Sequence matters: step 2 depends on Task 3.1, because `dashboard-integration` currently computes a nonexistent slot path and would fail to nuke its stack.

### Task 3.7 — Out of scope, follow-up elsewhere

`scripts/setup-worktree.sh` and `docker-compose.worktree.yml` in the **monorepo** are a rival implementation (PR #1894), documented as incompatible on three axes by `dev/docs/worktree-consolidation-analysis.md` (2026-04-15): offset ×10 vs ×100, shared-postgres-separate-databases vs postgres-per-worktree, shared vs isolated network. The recommended consolidation was never implemented (`dev.sh:408` is still `s * 100`). Under a native-only layout they are doubly obsolete. Deleting them is a monorepo PR, not a change to this repo.

### Verification for Phase 3

Static first:

```bash
bash -n dev/lib/workspace.sh dev/sync-context.sh dev/wt-down.sh
```

Then a full native round-trip, which exercises every task:

```bash
cd ~/work/ledidi-monorepo
git worktree add .claude/worktrees/wt-probe -b test/wt-probe origin/master
# EnterWorktree path: <repo>/.claude/worktrees/wt-probe   (explicit name — never omit)
./setup-stack.sh                       # deps + codegen, no Docker
sync-context
grep -c '{{' CLAUDE.local.md           # expect 0
grep -A2 'Ports (Worktree' CLAUDE.local.md   # expect the no-stack note
dev up                                 # allocates a slot
sync-context && grep -A6 'Ports (Worktree' CLAUDE.local.md   # expect real ports
git switch -c test/wt-probe-2 && sync-context                # drift test: must still resolve
wt-down                                # nukes stack, removes dir, keeps branch
git branch --list 'test/wt-probe*'     # both branches must still exist
docker ps -aq --filter label=com.ledidi.dev-workspace=wt-probe   # expect empty
```

The `git switch` step is the regression test for Task 3.1 — before the fix, `sync-context` silently skips the worktree there. The `git branch --list` step is the regression test for Task 3.4 — the whole point is that removal preserves branches.

---

## Documentation to update on completion

`CLAUDE.md` in this repo, which describes the pre-overhaul shape throughout:

- The `claude/` bullet lists `claude/skills/` as holding "explain-diff-html, fix-pr-feedback" and `skills.work/` as eight skills including `fix-feedback` and `review-pr`. Update for the four extracted skills and the two deletions.
- The `claude/agents.work/` description should note the three reviewers are now invoked by `subagent_type` from `code-review`.
- The **`dev/`** bullet documents `gwc`/`gwd` and `setup-worktree.sh`; rewrite for `wt-down` and native creation, and note that `setup-stack.sh` is deps+codegen only while Docker/ports come from `dev up`.
- The **Worktree workflow** section under "Key Patterns" describes `~/work/worktrees/{branch}` with `gwc`/`gwd` — replace with the native routing rule and the opt-in-stack point.
- The `zsh/.zshrc` bullet lists `gwc`/`gwd` among key custom functions, and the **Work agent config** section lists them among work shell functions. Both need updating.

## Sequencing

Phases 1 and 2 are independent of each other and of Phase 3; any order works.

Within Phase 3 the order is constrained: **3.5 gates the migration** (if repo-wide tooling degrades badly under nested worktrees, reconsider the whole native-only decision before deleting anything), then 3.1 → 3.2 → 3.3 → 3.4 must land before 3.6, since the cleanup depends on correct slot keying and on `wt-down` existing.
