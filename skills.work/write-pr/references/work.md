# Work pull requests

## Scope and reviewer context

- Keep one concern per PR. Separate prerequisite fixes, formatting, security,
  and observability work when they can land independently.
- Aim for fewer than 25 files and 1,500 changed lines. More than 40 files or
  3,000 changed lines requires a concrete reason; first look for a coherent
  split.
- Explain unexpected generated files, lockfile changes, migrations, copied
  patterns, and configuration changes.
- Check every behavior and verification claim against the final diff and
  completed checks. Use the migration names and API shapes that actually ship;
  remove claims left over from an abandoned implementation.

## Registries in the Ledidi monorepo

Use the team's risk-assessment format below for `services/registries` and
`apps/registries-frontend` changes, including affected shared dependencies.
Read `docs/sdlc/development-process.md` (§10.8.1) in the current checkout
before assessing risk. That document owns component defaults, change defaults,
quality gates, and traceability requirements. Use this reference for the team
PR format; do not infer policy from older PRs or commit history.

### Traceability and risk

The risk level is Standard, with the `risk:standard` label, unless I name
another level for the PR. Then use my level and its label: `risk:minor` or
`risk:major`. Apply exactly one risk label.

Read the changed code before filling in the Risk Evaluation table. Consider
the affected component, the change type, likelihood of issues, impact of
failure, and rollback difficulty. When that evidence points to Minor or Major,
keep Standard and tell me in the report which factor points elsewhere.

Use only verified Registries URS and work-item references from the task or
repository. Do not borrow another service's requirements or invent identifiers.
If a required reference is missing, report the traceability gap. Follow the
agent tracker instructions for locating work; this skill does not create
GitHub issues. Omit the URS table when no URS is directly affected.

### PR titles and commit messages

Use the team title format:

```text
<gitmoji> <Imperative description> [<actual URS ID>] risk:<level>
```

Tag the URS document, not its criteria: `[URS-REG-022]`, never
`[URS-REG-022.1.8]`. Use one tag; a change spanning two documents may carry one
tag each. Criterion identifiers belong in the body's URS table. Omit the
bracketed field when no URS applies. Choose the gitmoji for the change type.
PR titles omit a trailing issue number.
For Registries commits, use the same format and include the actual work-item
reference when applicable. SDLC requires a work-item reference for change
requests; URS implementations may omit it. Never fabricate a GitHub issue
number from a local tracker filename. Explain missing required references.

Keep the description useful as a release-note sentence. This convention
applies to new commits; changing a PR description does not authorize rewriting
existing commits. `write-commit` governs prose and optional message bodies.

### Before and after

A visual change is one the reviewer would otherwise start the stack to see:
layout, copy, icons, colours, a new screen, or an empty, loading or error
state. Every visual change gets a before and after pair in the body. A new
screen gets its after alone.

Capture each pair the same way: same story or route, same seeded data, same
viewport. Take the before from a worktree on the PR base (load `worktree`) and
the after from the branch. Prefer the Storybook story's
`iframe.html?id=<id>&viewMode=story` URL; `show-stories` resolves the IDs.
Capture with `npx playwright screenshot` from `apps/registries-frontend`, or
reuse a frame that browser verification already produced. Record a short
video instead when the change lives in a sequence: a multi-step flow, a drag,
an animation. Capture only from the local stack or Storybook with seeded demo
data.

Save the files in the main checkout's `.scratch/<effort>/screenshots/` as
`<state>-before.png` and `<state>-after.png`. Write each file's absolute path
into the Visual Changes table and pass the same absolute path to
`gh pr create` or `gh pr edit` with a repeated `--attach`; `gh` replaces each
local path in the body with the uploaded URL. `--attach` needs `gh` 2.99.0 or
newer. When `gh pr create --help` lists no `--attach`, stop and ask me to run
`brew upgrade gh`. The pair is done when `gh pr view --json body` shows an
uploaded URL for every image and no local path remains.

### PR body

Use the following structure. Replace placeholders with facts from the final
change. Keep simple changes concise; scale design detail with complexity and
risk. Under Changes, explain the technical approach and material decisions,
including the root cause for bug fixes. Under Safeguards, distinguish completed
checks from pending or deferred checks. Include material migration,
compatibility, privacy, and rollout concerns where they affect the assessment.

```markdown
## Risk Assessment: <Descriptive title>

### Scope

<What changes and the resulting user-facing behavior.>

| URS | Requirement |
| --- | --- |
| <Actual URS ID> | <Requirement description> |

### Visual Changes

| State | Before | After |
| --- | --- | --- |
| <Changed state> | ![<State> before](<absolute path>) | ![<State> after](<absolute path>) |

<Omit this section when the change has no visual change.>

### Reason for Change

<The problem or requirement that motivates the change.>

### Risk Evaluation

| Factor | Assessment |
| --- | --- |
| System Component | <Component and SDLC default risk> |
| Likelihood of Issues | <Very Low/Low/Medium/High and justification> |
| Impact of Failure | <Very Low/Low/Medium/High and justification> |
| Rollback Difficulty | <Easy/Moderate/Difficult/Very Difficult and justification> |

### Changes

1. **<Area>**: <Approach and relevant design decisions.>

### Safeguards

- **<Safeguard>**: <Mitigation and supporting verification.>

### Conclusion

**Risk Level: <Standard/Minor/Major>**

<Why this level fits the change, including any departure from defaults.>
```
