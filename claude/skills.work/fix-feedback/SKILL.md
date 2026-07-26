---
name: fix-feedback
description: Address a list of code review issues by spawning one subagent per issue, then review and push. Subagents may disagree with feedback when justified.
argument-hint: "<list of issues — one per line, or numbered>"
disable-model-invocation: true
---

## Purpose

Address a list of code review issues sequentially. For each issue, spawn a subagent that understands the issue, decides whether to fix it (or push back with reasoning), implements the fix with tests, verifies, and commits. After all issues are processed, a review subagent inspects the resulting commits. Finally, push the branch and report any unaddressed issues.

## Input

`$ARGUMENTS` contains the list of issues. Issues may be numbered, bulleted, or separated by blank lines. If `$ARGUMENTS` is empty, ask the user to provide the list and stop.

## Workflow

### Step 1: Parse issues

1. Split `$ARGUMENTS` into individual issues. Preserve the user's order — issues are addressed sequentially in that order.
2. Number them `1..N` for tracking.
3. Capture the current branch: `git branch --show-current`. Confirm this is not `master`/`main` before continuing — if it is, stop and ask the user.
4. Initialize a status table in memory: `{ issue_n: { summary, status: pending, reason: null, commit: null } }`.

### Step 2: For each issue, spawn a fix subagent (sequentially)

For each issue `i = 1..N`, spawn one subagent and wait for it to finish before moving to the next. Do **not** parallelize — later issues may depend on commits from earlier ones, and commits must be ordered.

Spawn with the `Agent` tool using `subagent_type: "general-purpose"`. **Do not pass a `model` field** — the subagent inherits the parent model (this is what fulfills the "same model" requirement).

Use this prompt template, filling in `{issue_number}`, `{total}`, `{issue_text}`, and `{branch}`:

```
You are addressing review feedback item #{issue_number} of {total} on branch `{branch}`.

## Issue
{issue_text}

## Your job

1. **Ground yourself.** Read `CLAUDE.local.md` at the repository root before doing anything else. If it does not exist, read `CLAUDE.md` instead. Then read every file it links to (markdown links, `@path` references, or paths mentioned as "see X" / "refer to X") that is plausibly relevant to this issue — skip links that are clearly off-topic (e.g., a docs file about deployment when the issue is about a UI bug). These linked files contain the conventions you must follow.

2. **Understand the issue.** Re-read the issue text. If it references specific files/lines, open them. If the issue is unclear or you need more context (e.g., "what reviewer X meant by Y"), fetch the PR for this branch and look at the conversation:
   - `gh pr view --json number,title,body,url` to find the PR
   - `gh pr view <number> --comments` and `gh api repos/{owner}/{repo}/pulls/<number>/comments` for inline review threads
   - Search for the relevant comment by file/line or keyword from the issue text

3. **Decide whether to fix.** You are allowed — and expected — to disagree with the feedback when you have a good reason (e.g., the feedback is based on a misunderstanding of the code, conflicts with project conventions in `CLAUDE.local.md`, or has already been addressed). If you disagree:
   - Do NOT make any code changes
   - Output a clearly labeled `DISAGREE:` section at the end explaining your reasoning, citing file:line and conventions
   - Skip the rest of the steps

4. **Implement the fix.** Make the minimal change that addresses the issue. Follow the conventions from `CLAUDE.local.md`. Do not bundle unrelated cleanup.

5. **Add tests.** If the fix changes behavior that isn't already covered, add tests for the scenario. If existing tests already cover it or the change is purely cosmetic (renames, comments, type-only), skip and note why.

6. **Verify.**
   - Run the project's type-check command on the touched workspace(s). Fix any errors you introduced.
   - Run the relevant test suite (the tests you added/modified, plus tests for the files you touched). All must pass.
   - If the project has a lint command and you touched code it covers, run it.

7. **Commit.** Stage only the files you intended to change. Write a focused commit message. Let the pre-commit hook run — if it fails, fix the underlying issue and retry (do NOT use `--no-verify`).

## Output

Report back with one of:

- `FIXED:` short summary of the change, plus the resulting commit SHA (`git rev-parse HEAD`)
- `DISAGREE:` your reasoning for not making changes
- `BLOCKED:` what went wrong (e.g., verification kept failing) and what state the working tree is in

Keep the report under ~200 words. Do NOT push.
```

After each subagent returns:

1. Update the status table with `status` (`fixed` / `disagreed` / `blocked`), `reason` (from the subagent's report), and `commit` (from `git rev-parse HEAD` if fixed — verify the SHA actually changed since the previous issue).
2. Run `git status --short` to confirm the working tree is clean (no leftover staged/unstaged changes from the subagent). If it isn't, surface this in the final summary as a problem with that issue.
3. Proceed to the next issue.

### Step 3: Review the cumulative diff

Once all issues are processed, spawn one review subagent. Same rule: no `model` field — inherit from parent. Use `subagent_type: "general-purpose"`.

Prompt template:

```
You are reviewing the commits added to branch `{branch}` during this session. The base is `{base_sha}` (HEAD before this session started — captured in Step 1).

## Your job

1. Read `CLAUDE.local.md` (or `CLAUDE.md`) at the repo root, plus the files it links to that look relevant to the changes you're reviewing.
2. Inspect every commit added since `{base_sha}`:
   - `git log {base_sha}..HEAD --oneline`
   - `git diff {base_sha}..HEAD`
3. For each commit, verify that it actually addresses the corresponding issue from the list below and does not introduce regressions, secret leaks, or violations of project conventions.

## Issues that were addressed
{status_table_with_fix_summaries}

## Output

Report:
- `CLEAN:` if every commit is sound — no further action needed
- `ISSUES:` with a bulleted list of problems found (file:line + what's wrong). Categorize as `must-fix` vs `nice-to-have`.

Read-only review — do NOT edit files.
```

If the reviewer returns `ISSUES:` with any `must-fix`, spawn one more fix subagent (same shape as Step 2) to address them, then re-run Step 3. Cap this loop at one re-review to avoid infinite churn — if the second review still finds must-fix issues, surface them in the final summary and stop.

### Step 4: Push

`git push` to the current branch's upstream. If no upstream is set, use `git push -u origin {branch}`.

If the **pre-push hook fails**:

1. Capture the hook's output verbatim.
2. Spawn one more fix subagent with the pre-push errors as the issue text, using the same template from Step 2. Tell it the failures came from the pre-push hook and must be resolved before pushing.
3. Retry `git push`. Allow at most two pre-push fix cycles. If it still fails after that, do not retry — surface the failure in the final summary.

### Step 5: Final summary

Print a compact summary to the user covering every issue from the original list:

```
Fixed (N):
  1. <issue summary> — <commit sha>
  2. ...

Disagreed (N):
  3. <issue summary> — <reason in one line>

Not fixed (N):
  4. <issue summary> — <reason: blocked, dirty tree, review must-fix unresolved, etc.>

Review verdict: <CLEAN | issues remaining>
Push: <pushed to origin/{branch} | failed: <reason>>
```

Be honest in the "Not fixed" section — anything that wasn't fully fixed-and-committed goes there, including issues blocked by verification failures, issues with leftover working-tree changes, and review must-fix items that couldn't be resolved.
