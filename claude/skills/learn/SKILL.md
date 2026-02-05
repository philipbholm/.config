---
name: learn
description: Extract learnings from GitHub PR review feedback to prevent repeating mistakes
argument-hint: "<pr-number>"
disable-model-invocation: true
allowed-tools: Bash(git *), Bash(gh *), Bash(mkdir *), Bash(ls *), Read, Write(/Users/philip/.config/dev/feedback/*), Glob, Grep
---

## Purpose

Extract reusable learnings from PR review feedback. Turn specific review comments into generalized principles that prevent the same mistakes from recurring.

## Input

$ARGUMENTS must contain a PR number. If missing, tell the user:

> Usage: `/learn <pr-number>`

## Step 1: Detect Repository

```bash
git remote get-url origin
```

Parse owner/repo from the remote URL:
- SSH: `git@github.com:owner/repo.git` → `owner`, `repo`
- HTTPS: `https://github.com/owner/repo.git` → `owner`, `repo`

## Step 2: Fetch All PR Feedback

Use GitHub MCP tools to fetch everything. If MCP tools are unavailable, fall back to `gh api`.

**Fetch all of these (paginate with `perPage: 100` until exhausted):**

1. **PR details** — `mcp__plugin_github_github__pull_request_read` with `method: "get"` — title and description for context
2. **Review comments** — `method: "get_review_comments"` — inline code review threads (primary source of learnings)
3. **Reviews** — `method: "get_reviews"` — review summaries with body text
4. **Comments** — `method: "get_comments"` — general PR conversation
5. **Diff** — `method: "get_diff"` — code context for understanding feedback

**Fallback** (if MCP tools fail):

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --paginate
gh api repos/{owner}/{repo}/pulls/{pr_number}/reviews --paginate
gh api repos/{owner}/{repo}/issues/{pr_number}/comments --paginate
gh api repos/{owner}/{repo}/pulls/{pr_number} -H "Accept: application/vnd.github.diff"
```

## Step 3: Filter Noise

**Discard all of the following:**

- Bot accounts: usernames containing `[bot]`, or matching `github-actions`, `codecov`, `dependabot`, `renovate`, `copilot`
- CI status messages and automated check results
- Emoji-only comments (just reactions, no substance)
- Contentless approvals: comments that are only "LGTM", "+1", "Looks good", "Approved", thumbs-up, or similar with no additional feedback
- Empty review bodies (approval/comment with no text)

**Include:**

- Inline review comments with feedback or suggestions
- Review bodies that contain actual written feedback
- Design discussion comments in the general conversation
- Comment threads that reveal deeper principles or patterns

## Step 4: Analyze and Synthesize

Transform the filtered feedback into reusable learnings:

- **Generalize** — turn "add null check on line 42" into a reusable principle about defensive programming
- **Explain consequences** — not just "do X" but "do X because failing to causes Y"
- **Group related feedback** — 5 separate comments about error handling become 1 comprehensive learning about error handling strategy
- **Include code examples** from the diff when they clarify the point (use short, focused snippets)
- **Strip all attribution** — no reviewer names, no timestamps, no "the reviewer said". Learnings stand on their own.
- **Target 3-10 learnings** per PR. If the PR has fewer than 3 substantive pieces of feedback, produce fewer learnings. Quality over quantity.

**If the PR has no substantive feedback** (all comments were filtered out, or only approvals remain):

Write a short file noting that no actionable learnings were found, and why (e.g., "PR received only approvals with no specific feedback").

## Step 5: Write Output

Write to `/Users/philip/.config/dev/feedback/{pr_number}.md`

Create the directory if needed: `mkdir -p /Users/philip/.config/dev/feedback`

### Output Format

```markdown
# Learnings from PR #{number}

{One sentence about what the PR was about — derived from the PR title and description.}

---

## 1. {Principle Title in Imperative Form}

{Explanation of the issue and WHY it matters. What goes wrong if you ignore this? Be specific about consequences.}

**Guideline:** {One-sentence actionable rule.}

---

## 2. {Next Principle Title}

{Explanation with consequences.}

{Optional: short code example from the diff if it clarifies the point.}

**Guideline:** {One-sentence actionable rule.}

---

(Continue for each learning...)
```

**Format rules:**

- Titles use imperative form: "Forward Props in Wrapper Components", not "Props should be forwarded"
- Each learning has a `**Guideline:**` line — one sentence, actionable, memorizable
- Separate learnings with `---` dividers
- Code examples use fenced code blocks with language tags
- No attribution anywhere — no names, no "reviewer X said", no timestamps

After writing the file, output the full absolute path so the user can open it:

> Wrote learnings to `/Users/philip/.config/dev/feedback/{pr_number}.md`
