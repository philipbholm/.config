# Context precedence

Repository files describe each service's architecture and domain. The shared
skills describe Philip's development and delivery workflows. Read both; apply
the service's documented mechanism to the shared engineering requirement.
For example, authorization is required across services, but registries'
`buildAuthorizedUseCase` is not the studies use-case API.

## Local development and verification

`worktree`, `dev-stack`, and the rendered root port table own local checkout,
dependency, service, and database setup. `verify-change` owns check scope.

The **Worktree development** section in `services/registries/CLAUDE.md` and the
setup examples in `.claude/skills/frontend-qa/SKILL.md` use an older stack.
Their `scripts/setup-worktree.sh`, `wt<N>` offsets, shared test databases,
fixed localhost ports, and raw Compose commands are obsolete for this setup.
Use the shared skills instead. The form-element and Storybook instructions
in repository context still apply.

Use the current test runner, setup file, and builders in the affected workspace.
The shared `coding-standards` testing reference governs test design; legacy
`.claude/agents/test-review.md` examples do not require Jest, global test setup,
or a different test naming convention.

The mutation-testing advice in `services/studies/AGENTS.md` means removing
duplicate behavioral coverage. Keep distinct integration and unit contracts
even when one mutation makes more than one test fail.

## Tracking and publishing

Read `.scratch/agents/issue-tracker.md` for the agent tracker. Instructions to
create GitHub issues in `services/admin/AGENTS.md` or the local frontend QA
skill do not replace that tracker. If no tracker exists, follow the global
setup rule before creating one.

Global authorization and draft-PR rules govern publishing reports, uploading
artifacts, posting comments, and changing PR state. A local skill's publishing
step does not authorize those actions by itself.

## Missing local references

For admin URS work, use `verification/admin/AGENTS.md` and
`urs/urs.schema.json`; the `urs` skill named by `services/admin/AGENTS.md` is
absent from this setup.

The `AGENTS.md` linked by
`services/analysis-room/src/adapters/duckdb/CLAUDE.md` is absent in the audited
checkout. If it is still missing when working there, identify the missing
reference and establish the SQL contract from the implementation and tests.
