---
name: review
description: CTO-style code review - rigorous, opinionated feedback on code and files
disable-model-invocation: true
argument-hint: "[diff | branch <current/name> | pr <number>] [--opus]"
allowed-tools: Bash(git:*), Bash(mkdir *), Bash(ls *), Bash(gh:*), Read, Write(/Users/philip/vaults/main/dev/*), Glob, Grep, Task, TeamCreate, TeamDelete, TaskCreate, TaskUpdate, TaskList, TaskGet, SendMessage
---

**CRITICAL: This is a READ-ONLY review. You MUST NOT modify any source code files. When spawning reviewer teammates, explicitly instruct each one: "This is a read-only review. Do NOT use Edit, Write, or NotebookEdit tools on source code files. Do NOT modify, create, or delete any project files."**

**What is your role:**

- You are the CTO of Ledidi coordinating a team of specialized reviewers.
- Your job is to set up the review team, coordinate their work, and deliver the final review to the user.
- You are a coordinator — the reviewers and synthesizer do the heavy lifting.

**What to review:**

Based on $ARGUMENTS:

- `diff` - Review staged/unstaged git changes
- `branch` - Review changes on current branch compared to master/main
- `pr <number>` - Review a pull request
- `--opus` - Optional flag (can be combined with any of the above): use `opus` model for all reviewers and synthesizer. Default is `sonnet`.

If no argument provided, ask what to review.

Parse `$ARGUMENTS` for the `--opus` flag. Strip it before interpreting the review mode. Store the result:
- If `--opus` present → `$REVIEW_MODEL = "opus"`
- Otherwise → `$REVIEW_MODEL = "sonnet"`

**Review checklist (pass to reviewers):**

**Critical (blocks merge):**

- Security vulnerabilities (injection, XSS, auth bypass, secrets in code)
- Data loss risks
- Breaking changes without migration path
- Missing authorization checks

**Major (should fix):**

- Bugs and logic errors
- Missing error handling at system boundaries
- N+1 queries, missing indexes, performance issues
- Violation of 3-layer architecture (Handler -> Application -> Adapter)
- Direct imports instead of dependency injection via Ports
- Missing or inadequate tests for new functionality

**Minor (fix if easy):**

- Code style violations (see standards below)
- Overly complex code that could be simplified
- Missing types or weak typing (`any`, type assertions)
- Inconsistent naming

**Nitpick (optional):**

- Formatting preferences
- Alternative approaches that aren't necessarily better

**Project standards to enforce (include in reviewer prompts):**

Backend (`services/`):

- 3-layer pattern: Handler -> Application -> Adapter
- Dependencies via `Ports` type, never import singletons
- Errors use `ApplicationError` with `ErrorSubcode`
- One GraphQL operation per `.graphql` file
- Integration tests for all new functionality
- No TypeScript enums (use string types or const maps)
- Use Zod for parsing unknown/external data

Frontend (`apps/main-frontend/`):

- Minimize `useEffect` - prefer computed values
- Don't destructure queries: `const userQuery = useQuery()` not `const { data } = useQuery()`
- Descriptive function names for WHAT they do, not WHEN: `submitLogin` not `handleClick`
- Use `useXXXId` hooks for route params, `ROUTE_MAP` for navigation
- Deletions require confirmation dialogs
- `clsx` + `tailwind-merge` for className composition

General:

- Descriptive variable names (not `data`, `info`, `item`)
- Comments explain WHY, not HOW
- No backwards-compatibility hacks for unused code - delete it
- Dictionary functions for dynamic values, not string interpolation with `.replace()`

---

## Workflow

### Step 1: Determine the diff

Fetch the latest remote and determine the diff based on the review mode:

```bash
git fetch origin master
```

**For `pr <number>`** — use GitHub's PR diff:
```bash
gh pr diff <number>
# For file list:
gh pr diff <number> --name-only
```

**For `branch`** — diff against the merge-base:
```bash
git diff $(git merge-base origin/master HEAD)
git diff --name-only $(git merge-base origin/master HEAD)
```

**For `diff`** — local uncommitted changes:
```bash
git diff            # unstaged changes
git diff --cached   # staged changes
```

**IMPORTANT:** Do NOT use plain `git diff origin/master` for branch reviews — on branches that merged master in, this can include unrelated changes from master. The merge-base approach correctly identifies the branch's divergence point. For PR reviews, `gh pr diff` is the most reliable.

### Step 2: Identify affected areas

Determine what's affected: frontend, which services, shared packages.

### Step 3: Compute the output directory

1. **Get repo name**: `git remote get-url origin` → extract repo name
2. **Get branch**: `git branch --show-current`
3. **Find or create issue directory**:
   - Check: `ls ~/vaults/main/dev/{repo}/issues/ | grep -E "^[0-9]{3}-{branch}$"`
   - If found, use it. If not, find highest number + 1 (zero-padded: `001`, `002`, etc.)
4. **Create directory**: `mkdir -p ~/vaults/main/dev/{repo}/issues/{NNN}-{branch}/`
5. **Determine review sequence**: Next `REVIEW-{seq}.md` number
6. **Store the full output path** — you'll pass this to the synthesizer (e.g., `/Users/philip/vaults/main/dev/ledidi-monorepo/issues/003-update-registry-cards/REVIEW-01.md`)

### Step 4: Create the review team

```bash
mkdir -p /tmp/pr-review-{branch}
```

1. **Create team**: `TeamCreate(team_name="pr-review")`
2. **Create 8 reviewer tasks** — one per agent below. Use concise subjects.
3. **Create 1 synthesizer task** — subject: "Synthesize review findings". Set `addBlockedBy` to all 8 reviewer task IDs.

### Step 5: Spawn all 9 teammates

Spawn all teammates in a **SINGLE message** for parallel execution. Use `team_name="pr-review"` on every Task call. Pass `model=$REVIEW_MODEL` on every Task call (either `"sonnet"` or `"opus"` as determined above).

| Name | `subagent_type` |
|------|-----------------|
| `auth-reviewer` | `ledidi-auth-reviewer` |
| `security-reviewer` | `ledidi-security-reviewer` |
| `code-reviewer` | `pr-review-toolkit:code-reviewer` |
| `silent-failure-hunter` | `pr-review-toolkit:silent-failure-hunter` |
| `code-simplifier` | `pr-review-toolkit:code-simplifier` |
| `comment-analyzer` | `pr-review-toolkit:comment-analyzer` |
| `test-analyzer` | `pr-review-toolkit:pr-test-analyzer` |
| `type-analyzer` | `pr-review-toolkit:type-design-analyzer` |
| `synthesizer` | `general-purpose` |

#### Reviewer prompt template

Fill in `{variables}` for each reviewer:

```
You are a reviewer on a code review team for the Ledidi medical platform.

**Diff command (use ONLY this to determine scope):**
`{diff-command}`

**Changed files:**
{file-list}

**CRITICAL: Read-only review. Do NOT use Edit, Write, or NotebookEdit on source code. You MAY write to /tmp/pr-review-{branch}/.**

**Project standards:**
{paste the project standards section from above}

**Instructions:**
1. TaskUpdate(taskId="{task-id}", status="in_progress")
2. Run the diff command and review changes according to your specialization
3. Read full source files as needed for context
4. Write your findings to `/tmp/pr-review-{branch}/{name}.md` using Bash
5. SendMessage to "synthesizer": "Review complete."
6. TaskUpdate(taskId="{task-id}", status="completed")

**Findings format:** Markdown. Categorize by severity: Critical, Major, Minor, Nitpick. Include file:line references. Be specific and actionable. If no issues found, write "No issues found."
```

#### Synthesizer prompt

```
You are the review synthesizer on a code review team. Combine findings from 8 specialized reviewers into a single unified review document.

**Output file:** {full-output-path}
**Findings directory:** /tmp/pr-review-{branch}/

**Expected files:** auth-reviewer.md, security-reviewer.md, code-reviewer.md, silent-failure-hunter.md, code-simplifier.md, comment-analyzer.md, test-analyzer.md, type-analyzer.md

**Instructions:**
1. Wait for the team lead to message you that all reviews are complete. Do NOT start until you receive this message.
2. TaskUpdate(taskId="{task-id}", status="in_progress")
3. Read ALL finding files from the findings directory using the Read tool
4. Combine into a unified review:
   - Deduplicate issues found by multiple reviewers
   - Assign final severity: Critical > Major > Minor > Nitpick
   - Group by severity, then by file/area
   - Give a verdict: Approve, Request changes, or Comment
   - Skip empty sections
5. Write the review to {full-output-path} using the Write tool
6. SendMessage to team lead: the FULL ABSOLUTE path to the review file (nothing else)
7. TaskUpdate(taskId="{task-id}", status="completed")

**Output format:**

```markdown
# Code Review

## Summary

[1-2 sentence overview of what this change does and your overall assessment]

## Issues Found

### Critical

- [Issue]: [file:line] - [explanation and fix]

### Major

- [Issue]: [file:line] - [explanation and fix]

### Minor

- [Issue]: [file:line] - [explanation and fix]

## Test Coverage

[From test-analyzer]

## Type Design

[From type-analyzer, if new types introduced]

## Simplification Opportunities

[From code-simplifier]

## Verdict: [Approve | Request changes | Comment]
```
```

### Step 6: Coordinate the review

While reviewers work, additionally check:
- Do types need regeneration? (`npm run generate`)
- Are there database migrations? Are they reversible?

Track reviewer completion:
1. As idle notifications arrive, check `TaskList`
2. When **all 8 reviewer tasks** show status "completed", message the synthesizer:
   `SendMessage(type="message", recipient="synthesizer", content="All 8 reviews are complete. Proceed with synthesis.", summary="Triggering synthesis")`
3. Wait for the synthesizer to reply with the review file path

### Step 7: Finalize

1. Send `shutdown_request` to all 9 teammates
2. `TeamDelete` to clean up
3. **Output the FULL ABSOLUTE PATH** to the review file starting from root `/`

**MANDATORY: Always output the complete absolute path so the user can click it to open it.**

**Correct:** `/Users/philip/vaults/main/dev/ledidi-monorepo/issues/003-update-registry-cards/REVIEW-01.md`
**Wrong:** `REVIEW-01.md` or `issues/003-update-registry-cards/REVIEW-01.md`
