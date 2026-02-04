---
name: create-issue
description: Create a feature description through discussion. Use when you need to draft a feature description.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Task, Write, Edit, Bash(git *), Bash(mkdir *), Bash(ls *)
---

# Feature Description Generator

Create clear, actionable feature descriptions through conversation.

---

## Output Directory

All issues are stored in `~/vault/main/dev/{repo}/issues/{NNN}-{branch}/ISSUE.md`.

**To determine the path:**

1. **Get repo name**: Run `git remote get-url origin` and extract the repo name (e.g., `git@github.com:org/ledidi-monorepo.git` → `ledidi-monorepo`)
2. **Get branch**: Run `git branch --show-current` (e.g., `update-registry-cards`)
3. **Determine issue number**:
   - Check if a directory already exists for this branch: `ls ~/vault/main/dev/{repo}/issues/ | grep -E "^[0-9]{3}-{branch}$"`
   - If found, use that existing directory
   - If not found, scan existing directories with `ls ~/vault/main/dev/{repo}/issues/` and find the highest number, then add 1 (e.g., if `002-*` exists, use `003`)
   - Format with zero-padding: `001`, `002`, etc.
4. **Create directory**: `mkdir -p ~/vault/main/dev/{repo}/issues/{NNN}-{branch}/`
5. **Write file**: `ISSUE.md` in that directory

---

## Your Task

1. **Determine output path** using the steps above
2. Analyze the initial prompt and identify ambiguities
3. Research the codebase first to understand context
4. Use **AskUserQuestion tool** to ask 1-4 clarifying questions at a time
5. Iterate with follow-up questions if needed
6. Generate a structured feature description
7. Save to the issue directory as `ISSUE.md` 

**Important:** Do NOT start implementing. Just create the description.

### Guidelines for Questions

- Always research the codebase first to help identify relevant questions
- Ask only critical questions where the initial prompt is ambiguous
- Use AskUserQuestion tool with 2-4 options per question
- Include helpful descriptions for each option to guide the user
- Use `multiSelect: true` when multiple options could apply
- Ask follow-up questions if there are still ambiguities

Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?

### Using AskUserQuestion Tool

Use the AskUserQuestion tool to present options interactively. Users can always select "Other" for custom input.

Example usage:
```json
{
  "questions": [
    {
      "question": "What is the primary goal of this feature?",
      "header": "Goal",
      "multiSelect": false,
      "options": [
        {"label": "Improve onboarding", "description": "Make it easier for new users to get started"},
        {"label": "Increase retention", "description": "Keep existing users engaged longer"},
        {"label": "Reduce support", "description": "Decrease support tickets through better UX"}
      ]
    },
    {
      "question": "Who is the target user?",
      "header": "Audience",
      "multiSelect": false,
      "options": [
        {"label": "All users", "description": "Feature applies to everyone"},
        {"label": "New users only", "description": "Focus on onboarding experience"},
        {"label": "Admin users", "description": "Administrative functionality"}
      ]
    }
  ]
}
```

You can ask up to 4 questions at once. Each question can have 2-4 options.

```markdown
# [Title]

## Summary

[2-3 sentences explaining what and why]

## Acceptance Criteria

- [ ] Specific, verifiable criterion
- [ ] Another criterion

## Out of Scope

- Item 1

## Notes

- Technical hints or context
```

**The `# [Title]` header is mandatory.** Every feature document must begin with a descriptive h1 title.

## Title Best Practices

- Short and descriptive - don't cram everything in
- Use imperative mood: "Add login validation" not "Adding login validation"
- No period at the end

## Description Best Practices

- **What**: Clear description of the feature
- **Why**: Context and motivation - what problem does this solve?
- **Who**: Target user or audience affected
- **Outcome**: What does success look like?

## General Guidelines

- One feature = one focused piece of work
- Link related issues: "Follow-up to #123" or "Blocked by #456"
- Avoid vague descriptions like "make it work"
- Be specific in acceptance criteria (not "works correctly" but "returns 200 status code")
- If scope grows during discussion, suggest splitting into multiple features

## When Done

Output the full absolute path to the issue file so the user can open it immediately. Always print the complete path, never a relative or abbreviated one.

Example: `/Users/philip/vault/main/dev/ledidi-monorepo/issues/003-update-registry-cards/ISSUE.md`
