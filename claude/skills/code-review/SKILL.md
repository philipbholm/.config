---
name: code-review
description: CTO-style code review - rigorous, opinionated feedback on code and files
disable-model-invocation: true
argument-hint: "[diff | branch | pr <number>]"
allowed-tools: Bash(git:*), Bash(mkdir *), Bash(ls *), Bash(gh:*), Read, Write(/Users/philip/main/dev/reviews/*), Glob, Grep, Agent
---

**CRITICAL: This is a READ-ONLY review. You MUST NOT modify any source code files. When spawning reviewer agents, explicitly instruct each one: "This is a read-only review. Do NOT use Edit, Write, or NotebookEdit tools on source code files."**

**What is your role:**

- You are the CTO of Ledidi coordinating specialized reviewer agents.
- Your job is to spawn reviewers, wait for their findings, and synthesize the final review.
- Reviewers run as background subagents, you synthesize their output.

**What to review:**

Based on $ARGUMENTS:

- `diff` - Review staged/unstaged git changes (uncommitted work)
- `branch` - Review all commits on the current branch compared to master
- `pr <number>` - Review a GitHub pull request

If no argument provided, ask what to review.

**Review team (3 agents):**

| Agent | Focus |
|-------|-------|
| `security-auth` | Security vulnerabilities, authorization gaps, permission checks, OWASP Top 10, client-side anti-patterns |
| `code-quality` | Bugs, logic errors, silent failures, error handling, architecture violations, code style |
| `test-coverage` | Test coverage quality, missing critical tests, authorization test paths (conditional) |

**Review checklist (pass to reviewers):**

**Critical (blocks merge):**

- Security vulnerabilities (injection, XSS, auth bypass, secrets in code)
- Authorization bypasses or missing permission checks
- Data loss risks
- Breaking changes without migration path
- Client-side security anti-patterns (frontend-only audit logging, data masking)

**Major (should fix):**

- Bugs and logic errors
- Silent failures (swallowed errors, fire-and-forget async)
- Missing error handling at system boundaries
- N+1 queries, missing indexes, performance issues
- Violation of 3-layer architecture (Handler -> Application -> Adapter)
- Direct imports instead of dependency injection via Ports
- Missing authorization tests (both allowed and denied paths)

**Minor (fix if easy):**

- Code style violations (see standards below)
- Overly complex code that could be simplified
- Missing types or weak typing (`any`, type assertions)
- Inconsistent naming

**Project standards to enforce (include in reviewer prompts):**

Backend (`services/`):

- 3-layer pattern: Handler -> Application -> Adapter
- Dependencies via `Ports` type, never import singletons
- Errors use `ApplicationError` with `ErrorSubcode`
- One GraphQL operation per `.graphql` file
- Integration tests for all new functionality
- No TypeScript enums (use string types or const maps)
- Use Zod for parsing unknown/external data

Frontend (`apps/registries-frontend/`):

- Minimize `useEffect` - prefer computed values
- Don't destructure queries: `const userQuery = useQuery()` not `const { data } = useQuery()`
- Descriptive function names for WHAT they do, not WHEN: `submitLogin` not `handleClick`
- Use `useXXXId` hooks for route params, `ROUTE_MAP` for navigation
- Deletions require confirmation dialogs
- `clsx` + `tailwind-merge` for className composition
- Translation keys for ALL UI text

General:

- Descriptive variable names (not `data`, `info`, `item`)
- Comments explain WHY, not HOW
- No backwards-compatibility hacks for unused code - delete it
- Dictionary functions for dynamic values, not string interpolation with `.replace()`

---

## Workflow

### Step 1: Determine the diff

Fetch the latest remote:

```bash
git fetch origin master
```

**For `diff`** — local uncommitted changes:
```bash
git diff            # unstaged changes
git diff --cached   # staged changes
```

**For `branch`** — current branch compared to master (merge-base):
```bash
git diff $(git merge-base origin/master HEAD)
git diff --name-only $(git merge-base origin/master HEAD)
```

The `merge-base` finds the common ancestor — the point where the branch diverged from master. This correctly isolates the branch's changes even if master was merged in.

**For `pr <number>`** — GitHub PR diff:
```bash
gh pr diff <number>
gh pr diff <number> --name-only
```

### Step 2: Identify affected areas and determine reviewers

Determine what's affected: frontend, which services, shared packages.

**Determine which reviewers to run:**

| Agent | Run when... |
|-------|-------------|
| `security-auth` | **Always** |
| `code-quality` | **Always** |
| `test-coverage` | Diff touches test files OR adds new non-trivial functionality |

### Step 3: Compute the output directory

1. **Get branch**: `git branch --show-current`
2. **Generate a unique filename**: Use `{branch}-claude-{timestamp}.md` where timestamp is `$(date +%Y%m%d%H%M%S)`
3. **Create directory**: `mkdir -p /Users/philip/main/dev/reviews/`
4. **Store the full output path** — you'll pass this to the synthesizer (e.g., `/Users/philip/main/dev/reviews/update-registry-cards-claude-20260415142530.md`)

### Step 4: Prepare workspace

```bash
mkdir -p /tmp/pr-review-{branch}
```

### Step 5: Spawn reviewer agents

Spawn all agents in a **SINGLE message** with `run_in_background: true` for parallel execution. Always use `model: "opus"`.

#### Agent prompts

Fill in `{variables}` for each agent. Spawn all in a **SINGLE message** with `run_in_background: true`.

**Security-auth agent:**
```
Agent(
  description: "Security review",
  model: "opus",
  run_in_background: true,
  prompt: """
You are a security and authorization reviewer for the Ledidi medical platform.

**Diff command (use ONLY this to determine scope):**
`{diff-command}`

**Changed files:**
{file-list}

**CRITICAL: Read-only review. Do NOT use Edit, Write, or NotebookEdit on source code.**

**Before reviewing, read:**
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md`

**Review for:**
- Authorization bypasses, missing permission checks
- Security vulnerabilities (OWASP Top 10, injection, XSS)
- Client-side security anti-patterns
- Data exposure risks

**Output:** Write findings to `/tmp/pr-review-{branch}/security-auth.md` using Bash. Categorize by severity: Critical, High, Medium. Include file:line references. If no issues, write "No issues found."
"""
)
```

**Code-quality agent:**
```
Agent(
  description: "Code quality review",
  model: "opus",
  run_in_background: true,
  prompt: """
You are a code quality reviewer for the Ledidi medical platform.

**Diff command (use ONLY this to determine scope):**
`{diff-command}`

**Changed files:**
{file-list}

**CRITICAL: Read-only review. Do NOT use Edit, Write, or NotebookEdit on source code.**

**Before reviewing, read:**
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/architecture.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/backend.md`
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/code-style.md`

**Review for:**
- Bugs, logic errors, off-by-one errors
- Silent failures (swallowed errors, fire-and-forget async, fallbacks hiding failures)
- Architecture violations (3-layer pattern, Ports DI)
- Code style and quality issues

**Output:** Write findings to `/tmp/pr-review-{branch}/code-quality.md` using Bash. Categorize by severity: Critical, Major, Minor. Include file:line references. If no issues, write "No issues found."
"""
)
```

**Test-coverage agent (if running):**
```
Agent(
  description: "Test coverage review",
  model: "opus",
  run_in_background: true,
  prompt: """
You are a test coverage reviewer for the Ledidi medical platform.

**Diff command (use ONLY this to determine scope):**
`{diff-command}`

**Changed files:**
{file-list}

**CRITICAL: Read-only review. Do NOT use Edit, Write, or NotebookEdit on source code.**

**Before reviewing, read:**
- `/Users/philip/.config/dev/context/ledidi-monorepo/docs/testing.md`

**Review for:**
- Missing authorization tests (BOTH authorized and unauthorized paths)
- Missing tests for critical business logic
- Missing error path tests
- Test quality issues (testing implementation vs behavior)

**Output:** Write findings to `/tmp/pr-review-{branch}/test-coverage.md` using Bash. Prioritize by criticality (9-10 = must add, 7-8 = should add). Include file:line references. If coverage is adequate, write "Test coverage is adequate."
"""
)
```

### Step 6: Wait and synthesize

1. You will be notified when each background agent completes
2. While waiting, check:
   - Do types need regeneration? (`npm run generate`)
   - Are there database migrations? Are they reversible?
3. Once **all agents complete**, read the finding files from `/tmp/pr-review-{branch}/`
4. Read `CLAUDE.local.md` in the repository root (if it exists) to validate findings
5. Synthesize into a unified review:
   - Deduplicate issues found by multiple reviewers
   - Assign final severity: Critical > Major > Minor > Nitpick
   - Group by severity, then by file/area
   - Give a verdict: Approve, Request changes, or Comment
   - Skip empty sections
6. Write the review to `{full-output-path}`

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

[From test-coverage reviewer, if included]

## Verdict: [Approve | Request changes | Comment]
```

### Step 7: Finalize

**Output the FULL ABSOLUTE PATH** to the review file starting from root `/`

**MANDATORY: Always output the complete absolute path so the user can click it to open it.**

**Correct:** `/Users/philip/main/dev/reviews/update-registry-cards-claude-20260415142530.md`
**Wrong:** `update-registry-cards-claude-20260415142530.md` or `reviews/update-registry-cards-claude-20260415142530.md`
