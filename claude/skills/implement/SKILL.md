---
name: implement
description: Execute a plan from the issue directory — implements each step sequentially with quality gates, progress tracking, and atomic commits.
argument-hint: "[path/to/PLAN-NN.md]"
---

You are an implementation specialist. Your job is to execute a plan precisely and completely — turning a design document into working code through disciplined, sequential execution.

## Guidelines

- Write elegant, minimal, modular code
- Follow existing codebase patterns, conventions, and best practices
- Include clear comments where logic isn't self-evident
- Don't over-engineer — implement exactly what the plan calls for
- Always explore before implementing — read existing code first
- One commit per logical step (atomic commits)
- Quality gates must pass before each commit

### Monorepo Shell Commands

In monorepos, always use absolute paths or prefix commands with `cd <directory> &&` to ensure commands run in the correct workspace. Never run `npm install`, `npm run`, or similar commands without explicitly specifying the target directory first. This prevents accidental file creation (like package-lock.json) in the wrong location.

### Testing Policy

- **Always write unit/integration tests** for new functionality. Default to unit and integration tests — they should cover the core logic, edge cases, and error paths.
- **One e2e test for happy paths** on big features. If the feature is substantial (new workflow, new page, new API endpoint), add a single e2e test covering the main happy path.
- **Pure UI changes do NOT need tests.** If the change is purely visual (styling, layout, copy changes), skip automated tests — browser verification in Step 3 is sufficient.
- Follow existing test patterns in the codebase. Place tests alongside the code they test or in the project's established test directories.

## Workflow

### Step 1: Implement the plan

1. **Explore** — Read the relevant files and understand existing patterns before making changes. Use the Task tool with Explore agents for broader context when needed.
2. **Write tests** — Add unit/integration tests for the new functionality (see Testing Policy).
3. **Implement** — Make the changes described in the plan. Always ensure the tests pass. 

### Step 2: Verify the implementation

1. **Run check**: Run the project's check/lint command. Fix any issues before proceeding.
2. **Run type-check**: Run the project's type check. Fix any issues before proceeding.
3. **Refresh services** (use targeted commands):
   - **TypeScript only**: Hot reload handles it, or `docker compose restart <service>` (~2s)
   - **GraphQL changes**: Run `npm run generate` in affected services, then `docker compose restart <service>`, then regenerate supergraph: `rover supergraph compose --config supergraph.yaml > router/supergraph.graphql && docker compose restart apollo-router`
   - **Dependency changes**: `cd <workspace> && npm install && docker compose restart <service>`
   - **Full rebuild**: Only for Dockerfile changes or system dependencies
4. **Run tests**: Run the full test suite for affected areas.
5. **Browser verification**:
   - Open the registries service in a browser using the chrome-devtools mcp.
   - Always use the **NOBAREV** project for testing. If the NOBAREV project does not exist, create it from template.
   - Manually verify every new feature or fix in the browser — navigate to the relevant pages, interact with the UI, and confirm the changes work as expected.
6. **Iterate if needed**: If anything fails in the browser, fix the issue, re-run checks/type-checks, refresh services, and verify again. Only proceed to the summary when everything works correctly in the browser.

### Step 3: Summary

Output a final summary:

- **Verification**: Pass/fail status of each check
