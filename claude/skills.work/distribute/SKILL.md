---
name: distribute
description: Use when a change to EXISTING shared code must be spread across a stack of interdependent ("stacked") pull requests — each PR a branch built on the previous — so the edit lands on the right branch, flows down the stack, and every PR's checks go green. Keywords: stacked PRs, rebase --update-refs, flow-up, rebase --onto, tree-equality gate, force-with-lease, silent reintroduction, drive pr-checks green.
---

# Distribute a change across a stacked PR set

A **stacked PR set** is a chain of branches (`base → dash/01 → dash/02 → … → dash/NN`), each with
its own PR, each built on the previous. A *cross-cutting* change (threading a param through
handler→app→adapter, removing a field, a review-fix touching shared code) usually doesn't belong to
one branch — it touches files introduced on different branches. This skill spreads that change so
**each PR's diff stays coherent** and **every PR's required checks go green**.

## First: do you even need to distribute?

| The change is… | Do this |
|---|---|
| **Additive & localized** — a new file/module/column that one branch owns | **Don't distribute.** Land it on the owning branch, then restack the tail (`git rebase --update-refs`). No reference commit, no owner-mapping. |
| **Cross-cutting** — modifies/removes existing code that many branches already touch | Distribute (rest of this skill). |

## The correctness invariant (read this first — it's the whole point)

Propagating a change down a stack means **replaying each branch's own commits** onto a rewritten
parent. That replay is not sound by construction:

> **A downstream commit that *added* content carrying the changed lines will re-apply it on a
> *clean* replay — no conflict fires, so it's silent.** Worse, if a still-later branch overwrites
> that file, the tip ends up clean while the *middle* branches silently keep the old content.

So you need **two gates**, not one:

1. **Destination** — the tip tree equals the reference tree (`git rev-parse tip^{tree}` ==
   `git rev-parse ref^{tree}`). Proves the final state; says nothing about the road.
2. **The road** — **every branch** is verified individually: grep each branch tree for leftovers
   (§Verify), and remember `pr-checks: SUCCESS` is a **path-filtered rollup**, not a build guarantee
   (a build job skipped by path filtering still rolls up green; `tsc` on an unchanged path won't run,
   and vitest doesn't typecheck).

`rerere` speeds repeated conflicts but **blind-replays** a recorded resolution onto a look-alike
conflict — inspect `git rerere diff` before each `--continue`.

## Two ways to apply a cross-cutting change

**Back up with tags first** (tags aren't dragged by `--update-refs`):
`for b in <branches>; do git tag bak/<ns>/$b "$b"; done` — `<ns>` = any label you pick (task+date).

### Method A — in-place edit (preferred when you can name the owner commits; git ≥2.38)
```bash
git switch <tip>
git rebase -i --update-refs <base>     # mark the commit(s) that introduced the lines as `edit`
# at each stop: make the change, git add -A, git rebase --continue
```
One rebase rewrites history **and moves every `dash/NN` ref atomically**; a conflict pauses it and a
single `git rebase --continue` resumes. This replaces the manual loop below for most work.

### Method B — author-once + distribute (when the change is broadly cross-cutting, you can't cleanly name per-commit owners, or you want an independently-green *oracle* tree to diff against)
1. **Author reference commit `R`** on the integration branch. Make the *entire* change as one commit
   and get it **genuinely green** — real `build-ts` + the affected test suites, not codegen alone —
   plus a grep proving completeness. `R` is the oracle: distribution rebuilds `R`'s exact tree across
   the stack, and gate #1 proves the reconstruction. *(Good task to delegate to an implementer +
   reviewer subagent.)*
2. **Map each file to its owner** (mechanical):
   ```bash
   git log --oneline --diff-filter=A <tip> -- <file>   # branch/commit that ADDED the file
   git diff <owner> <tip> -- <file>                     # empty ⇒ checkout-from-tip; non-empty ⇒ drift
   ```
   Owner = the branch that introduced **the final form of the lines you're touching** (not just the
   file — a file added on dash/03 whose relevant lines arrive on dash/09 is owned, for this change, by
   dash/09). *checkout-from-tip:* `git checkout <tip> -- ':(literal)<file>'` then commit. *drift files:*
   `git diff R^ R -- <files> > drift.patch; git apply --3way drift.patch`, resolve by hand keeping the
   branch's own content. *(If `git-absorb` is installed, `git absorb --and-rebase` auto-places
   modify/remove hunks onto their blame-owner commits — but not new files or multi-owner hunks.)*
3. **Flow-up.** Prefer `git rebase --update-refs <base>` from the tip (atomic). Fallback manual loop
   (needed pre-2.38, or when refs aren't a clean chain) — **must stop on halt**:
   ```bash
   order=$(git for-each-ref --format='%(refname:short)' 'refs/heads/dash/*' | sort)  # generate, don't hand-type
   prev=<base>; prevbak=bak/<ns>/<base>
   for b in $order; do
     git rebase --onto "$prev" "$prevbak" "$b" || { echo "HALT on $b — resolve, add, rebase --continue, then re-run from the NEXT branch with prev=$b prevbak=bak/<ns>/$b"; break; }
     prev="$b"; prevbak="bak/<ns>/$b"
   done
   ```
   On any halt: resolve keeping the change applied **and** the branch's other work, `git add`,
   `git rebase --continue`, then resume the loop from the next branch (its `prev`/`prevbak` are the
   just-finished branch). Run git loops under `bash -c` (zsh doesn't word-split).

## Verify (both gates — do not push until all pass)
```bash
# gate 1: destination
[ "$(git rev-parse <tip>^{tree})" = "$(git rev-parse <ref>^{tree})" ] && echo TREE-MATCH || echo MISMATCH
# gate 2: the road — leftovers on ANY branch (not just the tip), for removals/renames
for b in $order; do git grep -nI '<removed-or-renamed-token>' "$b" -- <paths> ':(exclude)*/generated/*' \
  && echo "LEFTOVER on $b"; done
# base untouched + stack strictly linear (tree-equality is content, not ancestry)
prev=<base>; for b in $order; do git merge-base --is-ancestor "$prev" "$b" || echo "NON-LINEAR at $b"; prev="$b"; done
```
On a gate-1 mismatch, `git diff <tip> <ref> --stat` points at the file → find the branch that
*introduces* that content and fix there, then re-flow (§Recovery). For a change that **adds a
reference** to a symbol (not a removal), the per-branch grep can't prove buildability — either
`git checkout $b && npm run generate && npm run build-ts` per source-changing branch, or after push
confirm the CI **build/test sub-job actually ran** (`gh run view <id> --json jobs`) rather than
trusting the rollup. A `NONE` on a PR whose diff changes buildable source is a red flag, not "expected."

## Push safely
```bash
git fetch origin
# preflight: nothing lost + stack not shifting under you
for b in $order; do [ "$(git rev-parse bak/<ns>/$b)" = "$(git rev-parse origin/$b)" ] || echo "$b: remote moved"; done
for n in <prs>; do gh pr view "$n" --json autoMergeRequest,baseRefName,mergeStateStatus; done  # disable auto-merge; record baseRefName
# backups stay LOCAL — do NOT push bak/* tags: a pushed tag can't be cleanly deleted on the remote, so it pollutes origin forever. Recovery relies on this clone; keep it until the stack lands.
git push --force-with-lease origin dash/02:dash/02 …      # NEVER plain --force
# postflight: bottom-up merge may have retargeted a PR mid-push
for n in <prs>; do gh pr view "$n" --json baseRefName; done  # each base still its expected parent?
```
`--force-with-lease` protects one ref against a fetch→push race; it is **blind to stack structure** —
a maintainer merging `dash/01` mid-distribution can auto-retarget/close downstream PRs, and your lease
still passes. Force-push also **detaches inline review comments and can dismiss approvals** — if the
stack is under live review, warn reviewers (post an old→new SHA map) or use **merge-forward** instead
of rebase. `--no-verify` skips the *entire* pre-push hook (including generated-file/scratch-file
guards this workflow relies on) — only bypass after confirming the *only* failure is a known-unrelated
one; capture the hook output and check.

## Drive pr-checks green
```bash
for n in <prs>; do gh pr checks "$n" --json name,state -q '.[]|select(.name|test("pr-checks"))|.state'; done
```
Only the **required** check gates. Path-not-triggered PRs legitimately show `NONE` (confirm "no
checks", not stuck). Flaky infra (parallel build, shared test DB) → `gh run rerun <id> --failed`. A
genuine failure on one branch = the distribution missed something there: fix on that branch, re-flow,
re-verify, re-push.

## Recovery / abort
- Mid-rebase: `git rebase --abort` returns to pre-rebase state.
- Full reset: `for b in $order; do git branch -f "$b" bak/<ns>/$b; done` (from the tag backups).
- **Second flow-up after a mid-flow fix:** once branches were rewritten, `bak/<ns>/*` are STALE
  (they point at *pre-rewrite* tips). Snapshot a **fresh** namespace from the once-rewritten tips
  (`for b in $order; do git tag ff1/$b "$b"; done`) and re-flow using `ff1/*` as the `prevbak` anchors.
  Using the old anchors double-replays or drops commits.

## Alternatives (prefer over Method B when they fit)
| Tool / approach | Prefer when |
|---|---|
| `git rebase -i --update-refs` (Method A) | You can name the owner commits; the change edits existing lines. **Default.** |
| `git absorb --and-rebase` *(needs install)* | Modify/remove hunks with clear blame owners; auto-maps owners. |
| merge-forward (commit on owner, `git merge` each child) | Stack is under live review or force-push is forbidden — preserves review anchoring (cost: merge commits). |
| `gt` (Graphite) / `git-branchless` *(needs install)* | Long-lived stacks — permanent restack + one-shot PR-sync; deletes the loop and half these gotchas. |

## General gotchas (cross-project)
- macOS bash is 3.2 — no `declare -A`; use `case`/parallel arrays. Run git loops under `bash -c`.
- Glob-magic paths (Next.js `[param]` dirs, `?`, `*`) need `-- ':(literal)<path>'` pathspecs.
- Never commit plan/spec/scratch files into the repo — a tracked scratch file breaks gate #1.

## This repo (Ledidi monorepo) specifics
- Stack `dash/01 … dash/27` (16 & 19 don't exist); base `dash/01`; integration/oracle branch =
  `test/dashboard-integration` (kept == stack tip, never pushed as a PR). Branch→PR map in the plan.
- `dev` not raw `docker compose`; package scripts (`npm run generate`, `build-ts`, `test`) not
  `npx`. Generated GraphQL/Prisma is **gitignored** — never `git add`; regenerate per branch.
- Node **24.15.0** for tests; run BE then FE suites **sequentially** (shared test Postgres).
- `pr-checks` is the only required check; Chromatic diffs / UI-Tests are non-required. Ensure the
  story-map confirmation box is in the PR body (`pr-story-map-reminder.yml`). Known pre-existing
  pre-push failure: `tsc-shell` (apps/shell baseUrl) — the sole case `--no-verify` is justified.
- gitmoji commit prefixes; PRs are drafts with `## Why` / `## What`.

## Success criteria
- [ ] gate 1: `<tip>^{tree}` == `<ref>^{tree}`
- [ ] gate 2: per-branch leftover grep clean on **every** branch; stack strictly linear; base untouched
- [ ] local `bak/<ns>/*` tags intact (NOT pushed to remote); all branches force-pushed (`--force-with-lease`, no lease rejections); PR base refs unchanged post-push
- [ ] every affected PR's required `pr-checks` = SUCCESS with the build/test sub-job actually run (NONE only where paths genuinely aren't triggered)
