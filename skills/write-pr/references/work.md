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

Read the changed code before classifying risk. Consider the affected component,
the change type, likelihood of issues, impact of failure, and rollback
difficulty. Explain departures from the SDLC's default classifications.
Choose Standard, Minor, or Major from the evidence and apply exactly one
matching GitHub label: `risk:standard`, `risk:minor`, or `risk:major`.

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

Include applicable URS identifiers; omit the bracketed field when none applies.
Choose the gitmoji for the change type. PR titles omit a trailing issue number.
For Registries commits, use the same format and include the actual work-item
reference when applicable. SDLC requires a work-item reference for change
requests; URS implementations may omit it. Never fabricate a GitHub issue
number from a local tracker filename. Explain missing required references.

Keep the description useful as a release-note sentence. This convention
applies to new commits; changing a PR description does not authorize rewriting
existing commits. `write-commit` governs prose and optional message bodies.

### Screenshots and recordings

A change the reviewer can see needs a picture. Include one when the change
alters rendered UI: layout, copy, icons, colours, a new screen, or an empty or
error state. Backend-only work, refactors with no rendered difference, tests,
tooling and dependency bumps carry no image.

Show the state the reviewer would otherwise have to start the stack to see. One
image per changed state is enough: a before and after pair when the change
alters a screen that already existed, a single image when the screen is new.
Crop to the component under review and say in one line what each image shows.

Record an animated GIF instead when the change lives in the sequence rather
than the final frame: a multi-step flow, a drag, an animation, or a state that
only appears mid-interaction. Keep it to the few seconds that carry the change.

Reuse what verification already produced. Browser verification under
`dev-stack` and `show-stories` both put the changed UI on screen; capture
there. When the change is visual and verification produced no usable frame,
open the affected screen and capture on purpose.

GitHub serves only images it hosts itself, and `gh` cannot upload one. Create
the pull request with its body first, then open it with the harness's browser
automation, edit the description, drop each file into the editor where it
belongs, and save so GitHub rewrites it into a hosted link. A harness without
browser automation, such as Codex or Cursor Agent, writes the body with each
file's local path on the line where the image belongs and reports which file
goes where, so the user can drag them in.

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

<Images or recordings of the changed screens, each with a one-line caption.
Omit this section when nothing rendered changes.>

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
