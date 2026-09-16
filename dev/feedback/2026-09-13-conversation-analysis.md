# Ledidi conversation analysis — 6–13 September 2026

The recurring problem was rework after agents chose the wrong local pattern, added unnecessary machinery, or verified a narrower scenario than the one you used. Most broad coding rules already existed. The highest-value context changes are concrete domain decisions, clearer ownership of behavior and tests, and fixing conflicting workflow instructions.

This is an analysis and a set of proposed context changes. No context, skill, script, monorepo source, Git branch, or running service was changed. The report is saved alongside the existing feedback audit and is not committed.

## Coverage and evidence

| Harness | Local history screened | Coverage limits |
| --- | --- | --- |
| Codex | 82 prior root sessions; 472 extracted user messages in Ledidi and .config during the window. All extracted messages were read, including routine approvals and unrelated .config turns which were excluded from findings. | Includes sessions started before September 6 and resumed during the week. The current request was excluded. Archived sessions were also searched. |
| Claude Code | 17 root sessions with in-window text; 81 natural human prose turns in 14 sessions, plus command-driven review output. | Relevant local text starts September 9. No September 6–8 records were found; .config Claude history ends September 3. Injected skills, subagents and notifications were not counted as complaints. |
| Cursor | 17 conversations: 11 Ledidi and 6 .config; 50 human user-role records after excluding one tool injection. | Ledidi records start September 10. No September 7–9 transcripts were found. The local GUI database had 50 older conversations, latest June 11, and added no week coverage. |

The window is September 6–13 inclusive, through the available records during this investigation. Codex’s UTC/Oslo midnight boundary was checked and added no messages. Cursor embeds UTC+2 timestamps. Counts describe screened records, not independent incidents; the same problem can appear in several harnesses. The harness named in a citation is where the issue was discussed, not proof that harness originally wrote the code.

The findings below use your corrections, surrounding assistant explanations and recorded checks. Code statements describe the revision inspected in that conversation. I did not re-review today’s monorepo or independently reproduce every historical defect. I read follow-up context around candidate issues and inspected the current shared guidance and its Git history. I did not treat every review request, “why” question, design choice, or assistant-generated warning as a confirmed defect.

This is a comprehensive inventory of the issues identifiable in the available local conversations, not a guarantee that deleted or missing conversations contained no additional issues. The older September 5 PR-feedback audit was used only to understand existing rules, not counted as evidence from this week. Exact transcript record links accompany each finding; Codex turn numbers are identifiers within this investigation’s extracted inventory.

## Recommended order

| Order | Context change | Why start here |
| --- | --- | --- |
| 1 | Add a focused analysis reference for terminology, table/validation ownership, freeze policy, input eligibility and chart conventions. Link the latest accepted domain decisions. | These concrete choices kept being rediscovered or contradicted across sessions. |
| 2 | Make the closest-example comparison apply before design recommendations and to the final code. Add a few current registries exemplars. | “Follow established patterns” already exists but repeatedly failed in practice. |
| 3 | Refine test ownership and readable-fixture examples; reconcile the blanket regression-test rule with appropriate visual verification. | Test quantity and abstraction repeatedly increased review time without proving new behavior. |
| 4 | Rewrite retained-data guidance to allow an explicitly pending atomic display while protecting mutation identity. Add the agreed dashboard transition behavior. | The current wording conflicts with approved UX, while other retention code targeted the wrong dashboard. |
| 5 | Tighten PR-relative scope and add a specific PR-split comparison step. Route existing-checkout writes through ownership checks. | This addresses unrelated edits, lost UI during splitting and duplicated sibling changes. |
| 6 | Make review include an immutable final working-tree snapshot. | The current pre-commit review order and HEAD-only comparison leave a documented gap. |
| 7 | Change grilling pacing and reconcile design-skill vocabulary with repository terms. | These are direct conflicts in the instructions, not missing generic advice. |
| 8 | Preserve the recent CI, verification, stack, metadata and rendering fixes; assess adherence before adding more rules. | Repeating or broadening them would restore the delays you just removed. |

All proposed implementation belongs in this repository. References should remain shared by Claude Code, Codex and Cursor. If implemented later, update skill metadata where the trigger changes, then render and check all worktrees as the repository already requires.

## Issue inventory

### 1. Names repeatedly omitted the domain concept

**Status:** Repeated correction; general rule already exists.

You repeatedly asked for variablePlacement rather than placement, optionDictionary rather than dictionary, and durationColumn rather than duration. Kaplan–Meier repeated the problem after the earlier analysis renames. Ownership reads also needed names that made their owner restriction visible. Some terms came from the spec itself: “usable” appeared there. This is stronger evidence for missing concrete vocabulary than for missing general naming advice.

**Suggested context fix:** Add a small analysis vocabulary reference with the agreed nouns and distinctions: variable placement identity, column name, column values, option dictionary, statistical event indicator, and registry event. Give the same operation the same name through layers. Before proposing a name, consult the current domain document and nearest comparable analysis. Keep this reference specific to analyses; do not turn every local variable into a long phrase.

**Files:** [dev/context/ledidi-monorepo/AGENTS.md](/Users/philip/.config/dev/context/ledidi-monorepo/AGENTS.md), [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/SKILL.md](/Users/philip/.config/skills.work/coding-standards/SKILL.md).

**Evidence:** [Codex, 2026-09-08, turn 98](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T21-40-32-01a08289-50aa-7873-ad08-c19ca9430510.jsonl:9) [Codex, 2026-09-09, turn 102](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T21-40-32-01a08289-50aa-7873-ad08-c19ca9430510.jsonl:397) [Codex, 2026-09-09, turn 113](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T08-01-01-01a084c1-617a-7150-bff8-9fd40ca57ebe.jsonl:9) [Codex, 2026-09-09, turn 199](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T13-56-56-01a08607-3b62-7880-bb9c-e0d1baf0b6ea.jsonl:125) [Codex, 2026-09-10, turn 311](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:731) [Codex, 2026-09-11, turn 411](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T14-46-22-01a09081-36e4-7180-93ec-afdd5537d8ce.jsonl:86) [Claude, record 225](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/433df48a-f01e-48bd-adb8-0e115b4cfd6b.jsonl:225)

### 2. Renames stopped partway through the API, or renamed an already-renamed symbol

**Status:** Confirmed implementation mistakes.

One rename produced variableVariablePlacements. Another changed helpers but left the generated AnalyzablePlacement type unchanged because its GraphQL and backend sources were not renamed. A separate explanation used an older PR revision while newer names were committed locally. “Rename across the PR” was not completed consistently.

**Suggested context fix:** For a cross-layer rename, identify the owning schema and generated consumers first. After generation, search the affected feature for old names and accidental doubled names, then inspect the diff. State which revision an explanation describes when local and remote differ. Keep the scope limited to the requested feature and affected consumers.

**Files:** [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md), [skills.work/coding-standards/references/typescript.md](/Users/philip/.config/skills.work/coding-standards/references/typescript.md).

**Evidence:** [Codex, 2026-09-09, turn 200](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T13-56-56-01a08607-3b62-7880-bb9c-e0d1baf0b6ea.jsonl:245) [Codex, 2026-09-09, turn 208](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T14-27-38-01a08623-5722-7742-af10-49c8d8aa9033.jsonl:77) [Codex, 2026-09-09, turn 216](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T14-27-38-01a08623-5722-7742-af10-49c8d8aa9033.jsonl:283)

### 3. Agents claimed established patterns without comparing the right examples

**Status:** Repeated correction across all three harnesses.

Codex first overstated lowercase domain values as a registries-wide convention, then found uppercase variables and medication examples. You later described PR 4568 as repeatedly departing from established backend and frontend patterns. The Claude pass confirmed shared-input, schema-factory, mapper, projection-update, and mock-builder differences. Existing standards already require two or three comparable examples. The failure is applying that comparison to the proposed and final code.

**Suggested context fix:** Make the comparison concrete: name the closest current example, identify the relevant shared behavior, and explain any departure. Add a short registries reference pointing to current form, mapper, projection, builder and analysis examples. Route design-only recommendations to this reference too. Do not force a full diff review merely to answer a design question. Refresh exemplars when their code changes.

**Files:** [skills.work/coding-standards/SKILL.md](/Users/philip/.config/skills.work/coding-standards/SKILL.md), [dev/context/ledidi-monorepo/AGENTS.md](/Users/philip/.config/dev/context/ledidi-monorepo/AGENTS.md).

**Evidence:** [Codex, 2026-09-09, turn 243](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T17-30-19-01a086ca-9a38-7a90-ae65-76d511306bf1.jsonl:61) [Codex, 2026-09-09, turn 274](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T20-02-01-01a08755-7bc7-73a2-9281-1c9e8324f4f8.jsonl:49) [Codex, 2026-09-10, turn 334](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T09-15-47-01a08a2c-343e-7d03-b4b4-e0ef16101050.jsonl:9) [Claude, record 5](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/007d34b3-7e6c-42d3-816d-091bfad54810.jsonl:5) [Claude, record 7](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/4830331d-3306-4574-aa87-e844b95f81f4.jsonl:7) [Cursor, record 15](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/9a4d1ddb-3bdb-4298-9def-feb207de9fd6/9a4d1ddb-3bdb-4298-9def-feb207de9fd6.jsonl:15)

### 4. Readability refactors moved complexity into hooks, helpers and styling props

**Status:** Repeated correction; existing abstraction rule insufficiently applied.

A requested page simplification became a hook returning a large state/setter bag, then a helper module with eleven tests, then was moved back after further questions. Test builders gained unnecessary timing/failure flexibility. Training styling travelled through several components as emptyIconClassName. These changes often made the files smaller without making the caller easier to understand.

**Suggested context fix:** Start readability changes with early returns, explicit branches and private same-file functions/components. Extract a hook only when it owns a coherent lifecycle or rule and reduces caller knowledge. For shared environment styling, inspect existing ancestor data attributes and CSS variants. Clarify that the three-real-cases rule concerns new shared abstractions; it does not forbid a private helper or using an existing shared component.

**Files:** [skills.work/coding-standards/SKILL.md](/Users/philip/.config/skills.work/coding-standards/SKILL.md), [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md), [skills/codebase-design/SKILL.md](/Users/philip/.config/skills/codebase-design/SKILL.md).

**Evidence:** [Codex, 2026-09-08, turn 53](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-10-39-01a07d7e-8644-7781-ae77-e5ed5009732a.jsonl:406) [Codex, 2026-09-08, turn 87](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T14-42-23-01a0810a-7dcd-7e91-b0fd-126ece792111.jsonl:449) [Codex, 2026-09-09, turn 117](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T08-10-24-01a084c9-f915-7db3-bd35-2a8ce7741b85.jsonl:9) [Codex, 2026-09-09, turn 285](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T20-02-01-01a08755-7bc7-73a2-9281-1c9e8324f4f8.jsonl:856) [Claude, record 250](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/0014aef0-0cda-4762-9f4b-c1e855c2719a.jsonl:250) [Claude, record 396](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/0014aef0-0cda-4762-9f4b-c1e855c2719a.jsonl:396) [Claude, record 621](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/0014aef0-0cda-4762-9f4b-c1e855c2719a.jsonl:621) [Cursor, record 42](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/84093959-85e3-42b5-b000-a57606485959/84093959-85e3-42b5-b000-a57606485959.jsonl:42)

### 5. Equivalent analysis code used different shapes and unnecessarily complex branches

**Status:** Repeated readability and consistency correction.

Frequency had a named complete result while numeric summary constructed it with intersections and duplicated status. Grouped chart conversion was inline while ungrouped conversion had a helper. Analysis-kind selection used nested conditions and a fallback that looked like frequency. Type-specific validation was spread across conditions. The dashboard update event also lacked the nonempty-name constraint present in comparable created/updated schemas, although application validation already rejected empty names. These were maintainability and schema-consistency problems; not every difference was a runtime defect.

**Suggested context fix:** When adding an analysis, compare definition, computation, result, mapper, chart and test organization with the selected current exemplar. Use explicit kind/type branches and named complete domain results. Compare the same editable invariant across created/updated schemas without duplicating a full schema-test matrix. Keep analysis-specific work in its analysis directory; let common dispatch code route to it. Explain useful differences instead of mechanically making all implementations identical.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/references/typescript.md](/Users/philip/.config/skills.work/coding-standards/references/typescript.md), [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md).

**Evidence:** [Codex, 2026-09-09, turn 131](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T08-37-40-01a084e2-f068-7b53-9f99-429e73cb9f09.jsonl:79) [Codex, 2026-09-09, turn 234](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T16-49-14-01a086a4-fc79-7d42-b83c-c9ef1c43e94c.jsonl:39) [Codex, 2026-09-09, turn 264](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T19-59-11-01a08752-e2e1-7ec3-a395-41f69cc8cca8.jsonl:35) [Codex, 2026-09-09, turn 274](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T20-02-01-01a08755-7bc7-73a2-9281-1c9e8324f4f8.jsonl:49) [Codex, 2026-09-09, turn 285](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T20-02-01-01a08755-7bc7-73a2-9281-1c9e8324f4f8.jsonl:856) [Codex, 2026-09-09, turn 286](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T20-02-01-01a08755-7bc7-73a2-9281-1c9e8324f4f8.jsonl:884) [Codex, 2026-09-11, turn 411](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T14-46-22-01a09081-36e4-7180-93ec-afdd5537d8ce.jsonl:86) [Codex, 2026-09-11, turn 416](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T16-52-54-01a090f5-0f15-7773-92cd-cc58fdc3038c.jsonl:9) [Codex, 2026-09-12, turn 439](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T11-10-55-01a094e2-52ce-7693-9e74-400e0fb61c85.jsonl:9) [Claude, record 583](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/0014aef0-0cda-4762-9f4b-c1e855c2719a.jsonl:583)

### 6. Dialog and update APIs included behavior no current caller needed

**Status:** Confirmed simplification requests; some preferences evolved.

The dashboard update operation implemented partial-patch semantics, no-op detection and extra response reads even though the form sent both fields and consumed only a summary. Dialogs added pristine-save gates, explicit IDs already supplied by shared Input, and extra dismissal plumbing. Cursor implemented a discriminated-union dialog when you meant separate create/edit components. That last exchange contained an ambiguous approval, so it is outcome mismatch rather than proven deliberate disregard.

**Suggested context fix:** Choose full update versus partial patch from actual callers and omission/null requirements. Return the shape those callers consume. Follow the local create/edit component pattern, sharing the form where appropriate. Inherit shared dialog/input behavior unless the task requires a departure. After comparing alternatives, state the selected concrete change before editing.

**Files:** [skills.work/coding-standards/references/backend.md](/Users/philip/.config/skills.work/coding-standards/references/backend.md), [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md), [agents/AGENTS.md](/Users/philip/.config/agents/AGENTS.md).

**Evidence:** [Claude, record 97](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/4830331d-3306-4574-aa87-e844b95f81f4.jsonl:97) [Claude, record 634](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/4830331d-3306-4574-aa87-e844b95f81f4.jsonl:634) [Cursor, record 69](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/84093959-85e3-42b5-b000-a57606485959/84093959-85e3-42b5-b000-a57606485959.jsonl:69) [Cursor, record 97](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/84093959-85e3-42b5-b000-a57606485959/84093959-85e3-42b5-b000-a57606485959.jsonl:97)

### 7. Compatibility layers were added for disposable pre-production analysis formats

**Status:** Repeated correction; feature-specific fact missing.

You asked to remove stored-analysis-definition compatibility and the deprecated groupingFor adapter because these analysis APIs were not in production. Codex explicitly said it added compatibility because deployment status was unclear. The current reliability reference already permits direct changes to confirmed disposable pre-production formats.

**Suggested context fix:** Record the scoped deployment/persistence decision for analysis definitions and APIs in the analysis context, with a date and a condition to re-check before release. Require coordinated current-client updates. Do not write “Ledidi is not in production” or authorize discarding clinical data. The missing fact should resolve the choice; another generic compatibility rule would duplicate existing guidance.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/references/correctness-and-reliability.md](/Users/philip/.config/skills.work/coding-standards/references/correctness-and-reliability.md).

**Evidence:** [Codex, 2026-09-09, turn 245](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T17-30-19-01a086ca-9a38-7a90-ae65-76d511306bf1.jsonl:1158) [Codex, 2026-09-09, turn 248](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T17-30-19-01a086ca-9a38-7a90-ae65-76d511306bf1.jsonl:1507) [Cursor, record 1](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/f76cb809-6740-44d1-873c-3b69b41c1017/f76cb809-6740-44d1-873c-3b69b41c1017.jsonl:1)

### 8. A typed GraphQL definition became JSON to accommodate another analysis kind

**Status:** Confirmed contract weakening in the historical implementation.

The conversation traced AnalysisCard.definition from a typed field to JSON because numeric summary had a different shape. Codex acknowledged this was a shortcut; JSON removed schema discoverability and generated client typing. The input design also needed restructuring when the next analysis had several independent inputs. Current backend rules say schema types align with domain models, but do not make this regression explicit.

**Suggested context fix:** Preserve a typed public contract when adding variants. Inspect existing union/oneOf patterns and current consumers before choosing the representation. An unused field may be removed under the agreed compatibility policy; JSON should represent genuinely unstructured data, not avoid modelling a known variant. Verify both input and output mappers through GraphQL.

**Files:** [skills.work/coding-standards/references/backend.md](/Users/philip/.config/skills.work/coding-standards/references/backend.md), [skills.work/coding-standards/references/typescript.md](/Users/philip/.config/skills.work/coding-standards/references/typescript.md).

**Evidence:** [Codex, 2026-09-09, turn 268](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T19-59-11-01a08752-e2e1-7ec3-a395-41f69cc8cca8.jsonl:579) [Codex, 2026-09-09, turn 234](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T16-49-14-01a086a4-fc79-7d42-b83c-c9ef1c43e94c.jsonl:39)

### 9. Dataframe operations were reimplemented with row loops and nested maps

**Status:** Repeated requested simplification.

Frequency copied dataframe columns into JavaScript arrays and counted with nested maps. Numeric summary repeated per-row checks after you had already requested Polars computations. A later dictionary-dataframe experiment was explicitly reverted, showing that “more Polars” is not the goal by itself.

**Suggested context fix:** For an analysis already using Polars, inspect supported column/group operations before writing observation loops. Keep the shortest clear combination of dataframe computation and result shaping. Do not require every dictionary lookup, formatting step or small result conversion to be a dataframe expression. Document the selected analysis exemplar rather than mandating broad Polars rewrites.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md).

**Evidence:** [Codex, 2026-09-09, turn 121](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T08-12-41-01a084cc-10c8-7cc1-90a8-3b8dea18695d.jsonl:51) [Codex, 2026-09-09, turn 275](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T20-02-01-01a08755-7bc7-73a2-9281-1c9e8324f4f8.jsonl:101) [Codex, 2026-09-10, turn 308](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:526) [Codex, 2026-09-10, turn 310](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:581) [Codex, 2026-09-10, turn 312](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:741)

### 10. Shared table guarantees were checked again inside each analysis

**Status:** Repeated architecture correction.

Finite-input and dictionary-membership validation appeared in individual calculations. You moved common integrity rules to table construction, then questioned the remaining frequency guards. Computation overflow is different: valid finite inputs can still produce invalid output. One assistant even recommended plain Error despite the existing typed-application-error rule; that was a recommendation, not a verified resulting change.

**Suggested context fix:** Write the ownership contract: table construction guarantees normalized column types and valid input values; analysis code owns its statistical exclusions and computed-output validity. Move tests with the guarantee. Retain checks at independently callable trust boundaries and keep safe typed errors. Require a reason for repeated validation rather than adding defensive guards automatically.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/references/backend.md](/Users/philip/.config/skills.work/coding-standards/references/backend.md), [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md).

**Evidence:** [Codex, 2026-09-10, turn 308](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:526) [Codex, 2026-09-10, turn 333](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T09-11-21-01a08a28-236c-7a73-b3fa-f5b93c32b1ea.jsonl:89) [Codex, 2026-09-11, turn 411](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T14-46-22-01a09081-36e4-7180-93ec-afdd5537d8ce.jsonl:86) [Codex, 2026-09-11, turn 416](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T16-52-54-01a090f5-0f15-7773-92cd-cc58fdc3038c.jsonl:9) [Codex, 2026-09-11, turn 419](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T16-52-54-01a090f5-0f15-7773-92cd-cc58fdc3038c.jsonl:197)

### 11. Historical options and source types were not separated cleanly from analysis eligibility

**Status:** Design change plus a confirmed implementation consequence.

The approved Kaplan–Meier spec originally required current event options and NUMBER-only duration. Later you chose historical options too. Therefore isCurrent and acceptedElementTypes were not simply repeated mistakes. However, removing isCurrent alone was insufficient: save validation used an empty patient scope, so historical options discovered through answers were missing. Selection configuration and scoped observation dictionaries have different sources.

**Suggested context fix:** Document separately: option ownership in design history, options present in the scoped data, source element eligibility, and normalized dataframe type. Preserve historical answers and reject foreign/nonexistent option IDs. When a decision changes, update the authoritative requirement and every affected save/run/picker path before deleting a guard. Keep source restrictions only where the current product decision requires them.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [dev/context/ledidi-monorepo/AGENTS.md](/Users/philip/.config/dev/context/ledidi-monorepo/AGENTS.md).

**Evidence:** [Codex, 2026-09-09, turn 125](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T08-12-41-01a084cc-10c8-7cc1-90a8-3b8dea18695d.jsonl:151) [Codex, 2026-09-09, turn 136](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T08-37-40-01a084e2-f068-7b53-9f99-429e73cb9f09.jsonl:705) [Codex, 2026-09-10, turn 347](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T10-25-25-01a08a6b-f3f7-7043-b3a3-685cafe6006d.jsonl:1865) [Codex, 2026-09-11, turn 410](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T14-46-22-01a09081-36e4-7180-93ec-afdd5537d8ce.jsonl:59) [Codex, 2026-09-11, turn 411](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T14-46-22-01a09081-36e4-7180-93ec-afdd5537d8ce.jsonl:86)

### 12. Centralizing variable eligibility added round trips and analysis-specific coupling

**Status:** Observed UX regression; broader redesign deferred.

The selectors used inconsistent filtering paths. The attempted consolidation then made changing analysis kind wait on network-only queries and embedded Kaplan–Meier-specific concepts in shared readers. You ultimately chose to scrap PR 4581, deliver Kaplan–Meier with simple selection, and defer the aligned table-first design. A rule that always puts all selection interaction on the backend would repeat the mistake.

**Suggested context fix:** Link the latest accepted analysis-input design and its delivery boundary. Distinguish authoritative save/run validation from interactive discovery. Before changing the picker API, trace requests on kind and variable changes and account for cached metadata, grain, repeat sources and agent callers. Keep future aggregation/calculated-variable work in the accepted roadmap, not in the current feature by implication.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [dev/context/ledidi-monorepo/AGENTS.md](/Users/philip/.config/dev/context/ledidi-monorepo/AGENTS.md).

**Evidence:** [Codex, 2026-09-09, turn 208](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T14-27-38-01a08623-5722-7742-af10-49c8d8aa9033.jsonl:77) [Codex, 2026-09-09, turn 211](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T14-27-38-01a08623-5722-7742-af10-49c8d8aa9033.jsonl:140) [Codex, 2026-09-11, turn 411](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T14-46-22-01a09081-36e4-7180-93ec-afdd5537d8ce.jsonl:86) [Codex, 2026-09-11, turn 421](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T17-35-48-01a0911c-553c-7923-994d-4eada64ed958.jsonl:9) [Codex, 2026-09-11, turn 422](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T17-35-48-01a0911c-553c-7923-994d-4eada64ed958.jsonl:128) [Codex, 2026-09-12, turn 435](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T10-31-26-01a094be-2d9a-7d92-81e2-1d057b6b89e8.jsonl:9) [Claude, record 9](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/dc099827-f955-4636-a137-4446fdc619a5.jsonl:9)

### 13. Tests multiplied the same contract across layers and retested shared infrastructure

**Status:** Repeated correction throughout the week.

You repeatedly removed duplicate real/training matrices, repeated computation checks in integration/GraphQL tests, and broad lifecycle/freeze/schema suites that did not add enough distinct coverage. But GraphQL mapping tests remained valuable, and a shared frequency fixture had eight consumers. The evidence does not support “delete integration tests” or “never share fixtures”.

**Suggested context fix:** Before adding a test, name the distinct contract and its owning level: table mechanics, arithmetic, application/authorization, transport mapping, UI interaction, or persisted browser journey. Inspect existing shared coverage. Keep one representative end-to-end connection where needed instead of copying the whole matrix. Refine the blanket regression-test rule for low-impact visual fixes: retain a stable regression assertion when it proves distinct behavior; use relevant story/browser evidence where that is the appropriate check.

**Files:** [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md), [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md).

**Evidence:** [Codex, 2026-09-08, turn 51](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-10-39-01a07d7e-8644-7781-ae77-e5ed5009732a.jsonl:9) [Codex, 2026-09-08, turn 58](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-10-39-01a07d7e-8644-7781-ae77-e5ed5009732a.jsonl:832) [Codex, 2026-09-08, turn 66](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-10-39-01a07d7e-8644-7781-ae77-e5ed5009732a.jsonl:1558) [Codex, 2026-09-09, turn 259](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T19-46-02-01a08746-d7c4-7991-b80a-bb9397827ba4.jsonl:9) [Codex, 2026-09-09, turn 279](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T20-02-01-01a08755-7bc7-73a2-9281-1c9e8324f4f8.jsonl:467) [Codex, 2026-09-09, turn 295](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T21-46-27-01a087b5-19cc-7ac2-a0bf-461cc24f564a.jsonl:99) [Codex, 2026-09-11, turn 379](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T08-51-38-01a08f3c-7261-7a12-805e-809d64f2d6a1.jsonl:64) [Codex, 2026-09-11, turn 409](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T14-46-22-01a09081-36e4-7180-93ec-afdd5537d8ce.jsonl:9) [Claude, record 454](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/4830331d-3306-4574-aa87-e844b95f81f4.jsonl:454)

### 14. Fixtures and assertions made correct results unnecessarily hard to verify

**Status:** Repeated readability correction.

Hard-to-read it.each scenarios, remote setup helpers, unexplained array positions, combined save/run failures, difficult arithmetic and flat risk-table cell arrays repeatedly required rewriting. You asked for simple values, grouped input rows next to their expected results, named scenarios, and blank lines before it declarations.

**Suggested context fix:** Extend the existing testing examples with one small calculation table and one named UI table-row assertion. Use hand-checkable numbers, meaningful fixture IDs, setup beside expectations, and separate independent failure scenarios. Group observations visibly when it helps; preserve an unsorted case when ordering is part of correctness. Add the requested blank-line convention. Do not require every fixture to be sorted or duplicate a large sample across all tests.

**Files:** [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md).

**Evidence:** [Codex, 2026-09-09, turn 129](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T08-37-40-01a084e2-f068-7b53-9f99-429e73cb9f09.jsonl:9) [Codex, 2026-09-10, turn 300](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:9) [Codex, 2026-09-10, turn 303](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:413) [Codex, 2026-09-10, turn 304](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:461) [Codex, 2026-09-10, turn 305](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:471) [Codex, 2026-09-10, turn 313](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-37-38-01a089d2-55f7-77e1-9480-65d182a63c85.jsonl:9) [Codex, 2026-09-11, turn 378](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T08-51-38-01a08f3c-7261-7a12-805e-809d64f2d6a1.jsonl:9) [Codex, 2026-09-11, turn 385](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T08-51-38-01a08f3c-7261-7a12-805e-809d64f2d6a1.jsonl:1686) [Claude, record 197](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/0014aef0-0cda-4762-9f4b-c1e855c2719a.jsonl:197)

### 15. Some tests passed without proving the behavior named by the test

**Status:** Confirmed coverage weaknesses from requested inspections.

Examples included a cross-event fixture that could fail for two different reasons, duplicate grouping values used to test multiple groupings, a “retired” ID with no actual retirement, clearing an already-null description, installing a failed list handler without triggering its request, history tests checking URLs without content, and a hand-written approximation of a real GraphQL query. These are separate from merely verbose tests.

**Suggested context fix:** For each negative test, make all unrelated conditions valid and assert the intended failure. For transitions, seed the before-state and trigger the actual request or mutation. For retirement, deletion and deduplication, inspect the real owning state rather than naming a fixture as if the state existed. Use the real query document when testing its compatibility. Strengthen these examples in the existing meaningful-assertion guidance.

**Files:** [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md).

**Evidence:** [Codex, 2026-09-09, turn 259](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T19-46-02-01a08746-d7c4-7991-b80a-bb9397827ba4.jsonl:9) [Codex, 2026-09-10, turn 316](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-37-38-01a089d2-55f7-77e1-9480-65d182a63c85.jsonl:88) [Codex, 2026-09-11, turn 407](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T11-38-12-01a08fd4-f136-7733-b66d-9b50965f5fb1.jsonl:9) [Codex, 2026-09-11, turn 416](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T16-52-54-01a090f5-0f15-7773-92cd-cc58fdc3038c.jsonl:9)

### 16. Ownership, registry isolation, deletion and audit coverage had distinct gaps

**Status:** Coverage gaps; not evidence of a production data leak.

The PR 4568 review found owner-without-write-permission cases missing for deleteAnalysis/saveDashboardLayout; same-owner cross-registry read/update cases missing; deletion fixtures too small to establish retention; omitted stored-event assertions; a one-row event query unable to detect duplicates; and incomplete ordered audit history. These were explicitly accepted for correction. Most current testing rules already describe the required invariants.

**Suggested context fix:** During final self-review of these behaviors, map each independent permission and scope to the enforcing boundary and its actual test. Keep complete stored-set assertions for duplicate/deletion guarantees and realistic sibling data for preservation. Reuse central lifecycle/policy tests where they prove the invariant. Do not recreate a large event-store test matrix for each use case.

**Files:** [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md), [skills.work/coding-standards/references/security-and-privacy.md](/Users/philip/.config/skills.work/coding-standards/references/security-and-privacy.md).

**Evidence:** [Codex, 2026-09-11, turn 407](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T11-38-12-01a08fd4-f136-7733-b66d-9b50965f5fb1.jsonl:9)

### 17. A direct API call with an omitted patient flag was not covered for a draft registry

**Status:** Confirmed missing boundary case; desired policy must remain explicit.

The resolver defaulted omitted isTrainingPatient to false, selecting real patients even when the registry was not live. The existing omitted-flag test used a live registry. The conversation added a draft-registry case; it did not establish a general rule that omission should select training data.

**Suggested context fix:** Record where the default lives and whether registry status changes it. Test the direct transport default with distinguishable real/training observations and the relevant registry status. Make internal use-case selection explicit when that is the contract. Keep this example with analysis population semantics, not as a guessed global default.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md).

**Evidence:** [Codex, 2026-09-07, turn 5](/Users/philip/.codex/sessions/2026/09/05/rollout-2026-09-05T16-11-38-01a071e9-20ef-79e3-b7e2-67c8cb0ef956.jsonl:812) [Codex, 2026-09-08, turn 64](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-10-39-01a07d7e-8644-7781-ae77-e5ed5009732a.jsonl:1428) [Codex, 2026-09-08, turn 65](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-10-39-01a07d7e-8644-7781-ae77-e5ed5009732a.jsonl:1455)

### 18. Storybook dependencies were missed when production behavior changed

**Status:** Confirmed build and fixture failures.

The frequency fixture import worked in TypeScript/Vitest but failed Storybook because Vite lacked the alias. Separately, a new dashboard permissions query was absent from page-story mocks: every story became read-only, one interaction failed, and other snapshots silently changed. Passing an unrelated test runner did not establish story correctness.

**Suggested context fix:** When adding a dependency, query, provider, alias or permission gate, inspect the affected stories and the runner that renders them. Use existing permission mocks with explicit actor capabilities so each story reaches its claimed state. Require a representative enabled/disabled story check when permission changes affect rendering. Current fixture-branch guidance already covers this; add these concrete triggers.

**Files:** [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md), [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md), [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md).

**Evidence:** [Codex, 2026-09-09, turn 145](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T11-16-44-01a08574-92f0-7483-9ef6-ec4c0f89f22b.jsonl:9) [Claude, record 5](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/164280f7-ddb0-4fd2-a007-bd12de1089f4.jsonl:5) [Claude, record 256](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/164280f7-ddb0-4fd2-a007-bd12de1089f4.jsonl:256)

### 19. Common chart states and presentation diverged across analysis kinds

**Status:** Repeated visible inconsistency; some presentation decisions changed.

The three analyses presented “Nothing to analyse yet” differently. Frequency used category-array length even when every count was zero; that behavior had earlier been defended using an existing test, then you explicitly changed it. Legends, number typography and missing labels also drifted. Existing tests describe behavior; they do not settle product intent.

**Suggested context fix:** Add an analysis-chart reference reached by the analytics/front-end condition. Point to the shared empty/error component, legend, tooltip content and number formatting. Record the accepted distinction between no observations, all-missing values, a valid numeric zero, suppressed results and invalid definitions. At a new-family review, compare the same state across sibling charts. Do not collapse distinct backend states solely to make their appearance match.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md).

**Evidence:** [Codex, 2026-09-09, turn 152](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T11-22-43-01a0857a-0cb3-7602-93bc-89aa9dcb9ca3.jsonl:9) [Codex, 2026-09-09, turn 272](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T19-59-11-01a08752-e2e1-7ec3-a395-41f69cc8cca8.jsonl:695) [Codex, 2026-09-12, turn 448](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:1091) [Codex, 2026-09-12, turn 454](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:1516) [Codex, 2026-09-12, turn 455](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:1565) [Codex, 2026-09-12, turn 456](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:1681)

### 20. Tooltip fixes missed pointer transitions, positioning and truncation cases

**Status:** Repeated user-observed defects.

Numeric-summary label hover did not work; wrapped tooltip text had excess space. Kaplan–Meier mixed a plot tooltip anchored to an empty span with a separate dark censor tooltip. After that changed, the tooltip jumped between cursor and tick. Further fixes covered continuous durations, excessive decimals, typography, alignment and tooltips on labels that were not truncated. The empty-span diagnosis was initially a code-based hypothesis, not yet a browser reproduction.

**Suggested context fix:** Use the existing chart tooltip system and one positioning owner. Define pointer versus keyboard selection, movement over a tick and off a line, and truncated versus complete labels. Verify the actual transitions in a browser with short/long labels and grouped/ungrouped data. Use real chart primitives before custom SVG geometry; retain custom markers only for behavior the library does not supply.

**Files:** [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md), [skills.work/dev-stack/references/browser-verification.md](/Users/philip/.config/skills.work/dev-stack/references/browser-verification.md), [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md).

**Evidence:** [Codex, 2026-09-09, turn 180](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T12-14-04-01a085a9-0fd5-70e1-8125-941bd990ff3d.jsonl:390) [Codex, 2026-09-09, turn 183](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T12-14-04-01a085a9-0fd5-70e1-8125-941bd990ff3d.jsonl:1020) [Codex, 2026-09-12, turn 439](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T11-10-55-01a094e2-52ce-7693-9e74-400e0fb61c85.jsonl:9) [Codex, 2026-09-12, turn 441](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:9) [Codex, 2026-09-12, turn 443](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:736) [Codex, 2026-09-12, turn 445](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:863) [Codex, 2026-09-12, turn 447](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:1045) [Codex, 2026-09-12, turn 450](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:1201) [Codex, 2026-09-12, turn 451](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:1362) [Codex, 2026-09-12, turn 454](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:1516)

### 21. Small cards clipped content, acquired scrollbars, or displaced chart labels

**Status:** Repeated layout correction.

Error messages were initially above the card centre. Centering plus overflow-hidden then clipped long messages. A later Chromatic “crop” was actually scrollable content, which the browser confirmed accessible. Kaplan–Meier introduced chart-card scrolling and later cramped risk-table popovers, shifted x-axis labels, and hid the legend with the table. Some legend placement preferences changed again on September 13.

**Suggested context fix:** Record the current chart-card layout contract: charts fit their allocated card; long explanatory messages remain reachable; optional risk-table content has an explicit compact-card presentation. Compare smallest supported cards, long labels and grouped/ungrouped tables in the real layout. Keep only the latest agreed legend/table behavior in domain guidance. Do not generalize “no chart scrollbars” into clipping every error message.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/dev-stack/references/browser-verification.md](/Users/philip/.config/skills.work/dev-stack/references/browser-verification.md).

**Evidence:** [Codex, 2026-09-09, turn 195](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T13-35-57-01a085f4-07a5-7792-854e-c11d34ac2427.jsonl:9) [Codex, 2026-09-09, turn 219](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T16-18-34-01a08688-e687-7dc3-8cf7-bfe672ad2625.jsonl:9) [Codex, 2026-09-09, turn 224](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T16-18-34-01a08688-e687-7dc3-8cf7-bfe672ad2625.jsonl:488) [Codex, 2026-09-09, turn 227](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T16-18-34-01a08688-e687-7dc3-8cf7-bfe672ad2625.jsonl:928) [Codex, 2026-09-12, turn 439](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T11-10-55-01a094e2-52ce-7693-9e74-400e0fb61c85.jsonl:9) [Codex, 2026-09-12, turn 468](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:2280) [Codex, 2026-09-13, turn 471](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T12-32-10-01a0952c-b639-7672-b1b6-f6cbc299a810.jsonl:2417)

### 22. Loading and animation fixes repeatedly changed unrelated dashboard geometry

**Status:** Repeated defects after attempted fixes.

The real/training toggle moved when the title arrived; a page spinner appeared above the future card; the Add analysis button changed size, opacity and position; hardcoded skeleton cards did not match actual cards. Tests passed while you still saw flicker. Live/training switching removed whole cards when you wanted a stable shell with loading only in the result area.

**Suggested context fix:** Separate initial load, dashboard switch and result/environment switch. Record which geometry stays fixed and which content is pending. Preserve card shells when only results change; never retain live values under a training label. For a reported flicker, compare the same dashboard on refresh and navigation using slowed motion or frame evidence when needed. Verify empty/populated dashboards and delayed titles. Do not mandate animated loading or fixed skeleton counts.

**Files:** [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md), [skills.work/dev-stack/references/browser-verification.md](/Users/philip/.config/skills.work/dev-stack/references/browser-verification.md), [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md).

**Evidence:** [Codex, 2026-09-11, turn 369](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:1833) [Codex, 2026-09-11, turn 370](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:2304) [Codex, 2026-09-11, turn 371](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:2436) [Codex, 2026-09-11, turn 372](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:2552) [Codex, 2026-09-11, turn 373](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:2605) [Codex, 2026-09-11, turn 401](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T09-20-16-01a08f56-aa7d-7f31-b541-5c897337d0ea.jsonl:357) [Claude, record 264](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/bc9ba781-4278-4b83-b143-6c6b12279d2a.jsonl:264) [Claude, record 1043](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/bc9ba781-4278-4b83-b143-6c6b12279d2a.jsonl:1043) [Claude, record 1143](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/bc9ba781-4278-4b83-b143-6c6b12279d2a.jsonl:1143)

### 23. The retained-data rule conflicted with an approved atomic dashboard switch

**Status:** Instruction conflict, plus a real stale-target failure in another revision.

Claude treated the current “identity matches the request” rule as forbidding the coherent old dashboard remaining visible until the next dashboard is ready. You approved an atomic replacement. Separately, Codex found a real defect: after A→B failed, Add analysis could still target retained A from B’s error page. Smooth retention and correct action targeting must both be specified.

**Suggested context fix:** Rewrite the rule around displayed identity and operation identity, scoped to transitions within the same tenant and authorization context. Clear retained content when that security context changes. If a transition retains A, retain A’s title and content coherently, expose the requested B’s pending or failed state, and define whether actions are disabled or explicitly target A. When B fails, prevent an action labelled as belonging to B from mutating A. Replace the whole displayed snapshot together. Test failure, retry, cancellation and cached return. Do not merely weaken the stale-data rule.

**Files:** [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md).

**Evidence:** [Claude, record 976](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/bc9ba781-4278-4b83-b143-6c6b12279d2a.jsonl:976) [Claude, record 1136](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/bc9ba781-4278-4b83-b143-6c6b12279d2a.jsonl:1136) [Codex, 2026-09-11, turn 367](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:1502)

### 24. Motion rules missed portals, keyboard interaction and reduced-motion controls

**Status:** Confirmed findings from the requested animation review.

The browser review found tooltips travelling for 400 ms during keyboard navigation, portaled filters missing motion attributes, a removal button growing to 125%, focus controls fading, loader dots scaling, and sidebar width animation on keyboard input. Other fixes uncovered lingering dialog focus lock and entry animation replay. Some were inherited dashboard behavior rather than introduced by PR 4572.

**Suggested context fix:** For motion work, trace all rendered surfaces, including portals and shared controls. Apply keyboard and reduced-motion behavior at the actual owner. Verify focus release and immediate keyboard feedback. Keep any specialized animation reference behind a motion-specific trigger; do not impose the entire animation workflow on ordinary copy or layout changes.

**Files:** [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md), [skills.work/dev-stack/references/browser-verification.md](/Users/philip/.config/skills.work/dev-stack/references/browser-verification.md).

**Evidence:** [Codex, 2026-09-11, turn 387](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T09-16-22-01a08f53-184c-7681-9eb3-45e6e2fd69e2.jsonl:9) [Codex, 2026-09-11, turn 369](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:1833)

### 25. Popover focus and hover styling made state misleading

**Status:** Confirmed visual defect; later simplification changed the chosen mechanism.

The first dashboard row received focus styling while another row was selected, so two rows looked selected. Row and icon hover backgrounds were identical. Training mode also exposed grey backgrounds on orange surfaces. A selected-row autofocus workaround was later removed in a simplicity pass. The durable requirement is distinguishable states, not permanently preserving that particular workaround.

**Suggested context fix:** Use shared menu/dialog defaults first. Make selected, focused and hovered states visually distinguishable across real/training surfaces. Verify reopening with keyboard and pointer against the actual CSS. Add a focus override only where the default fails the required interaction; revisit any associated tests when that custom behavior is intentionally removed.

**Files:** [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md).

**Evidence:** [Codex, 2026-09-11, turn 395](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T09-20-16-01a08f56-aa7d-7f31-b541-5c897337d0ea.jsonl:109) [Codex, 2026-09-11, turn 397](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T09-20-16-01a08f56-aa7d-7f31-b541-5c897337d0ea.jsonl:145) [Codex, 2026-09-11, turn 399](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T09-20-16-01a08f56-aa7d-7f31-b541-5c897337d0ea.jsonl:256) [Codex, 2026-09-11, turn 402](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T09-20-16-01a08f56-aa7d-7f31-b541-5c897337d0ea.jsonl:473) [Codex, 2026-09-11, turn 405](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T09-20-16-01a08f56-aa7d-7f31-b541-5c897337d0ea.jsonl:565) [Claude, record 326](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/4830331d-3306-4574-aa87-e844b95f81f4.jsonl:326)

### 26. Analysis forms cleared valid selections and hid fields unnecessarily

**Status:** Confirmed behavior, followed by an explicit UX preference.

Kaplan–Meier duration selection cleared event indicator/options/grouping even when the same duration was selected again. The later assessment confirmed those event options no longer depended on duration. Fields appeared only after earlier selections, although you wanted all inputs visible once kind was chosen. Other analyses already preserved selection and displayed incompatibility.

**Suggested context fix:** When changing candidate logic, re-evaluate reset dependencies. Preserve still-valid user input and handle incompatibility explicitly. Record the agreed visibility and dependency behavior for analysis forms. Test reselecting the same value and switching away/back. Keep missing answers distinct from censored answers in the explanatory copy.

**Files:** [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md), [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md).

**Evidence:** [Codex, 2026-09-07, turn 40](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T11-49-48-01a07b46-1e31-71a0-a741-7ec6c5042d65.jsonl:1931) [Codex, 2026-09-12, turn 439](/Users/philip/.codex/sessions/2026/09/12/rollout-2026-09-12T11-10-55-01a094e2-52ce-7693-9e74-400e0fb61c85.jsonl:9)

### 27. Registry freeze incorrectly blocked dashboard and analysis operations

**Status:** Explicitly confirmed product-policy gap.

You first exempted dashboard operations, then found that analysis mutations remained freeze-gated and called that a mistake. The correction named createAnalysis, deleteAnalysis, saveAnalysisFilter and saveDashboardLayout. Generic mutation gating did not reflect the domain effect. The current analysis context does not state the freeze policy.

**Suggested context fix:** Add the concrete domain decision: registry freeze does not block the agreed personal-dashboard and analysis operations; authorization and ownership still apply. Select freeze policy from the operation’s domain effect rather than whether it is a mutation. Keep patient/design operations outside this exemption. Review the central policy coverage and comments when adding an operation.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md).

**Evidence:** [Cursor, record 75](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/9a4d1ddb-3bdb-4298-9def-feb207de9fd6/9a4d1ddb-3bdb-4298-9def-feb207de9fd6.jsonl:75) [Cursor, record 11](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/253357ea-7939-4f49-89d6-90a2cf0e004e/253357ea-7939-4f49-89d6-90a2cf0e004e.jsonl:11) [Cursor, record 16](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/253357ea-7939-4f49-89d6-90a2cf0e004e/253357ea-7939-4f49-89d6-90a2cf0e004e.jsonl:16)

### 28. A frequency-only guard disabled the global Add analysis entry point

**Status:** Confirmed stale feature assumption.

NOTHING_TO_COUNT persisted after multiple analysis kinds existed. You explicitly wanted write permission to govern the entry point, with input suitability handled inside the selected analysis. Related numeric-summary work added filter-disabling behavior that you later removed from that PR.

**Suggested context fix:** Record the distinction between permission to open the analysis form and validity of a particular input. On a new analysis family, audit old single-kind names, copy and guards. Handle missing eligible inputs inside the relevant form. Keep resource/loading constraints explicit where an operation genuinely cannot be submitted; do not make the permission decision stand in for all state handling.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md).

**Evidence:** [Cursor, record 1](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/84093959-85e3-42b5-b000-a57606485959/84093959-85e3-42b5-b000-a57606485959.jsonl:1) [Codex, 2026-09-09, turn 204](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T14-27-38-01a08623-5722-7742-af10-49c8d8aa9033.jsonl:9) [Codex, 2026-09-09, turn 214](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T14-27-38-01a08623-5722-7742-af10-49c8d8aa9033.jsonl:204)

### 29. Mutation completion and Apollo cache handling diverged from local patterns

**Status:** Confirmed convention correction; one residual risk was reported, not reproduced.

Dashboard list mutations manually rewrote cache entries and __typename instead of using the neighbouring refetchQueries pattern. Missing successful mutation data sometimes caused a silent return. The custom cache logic had a reason: avoid treating post-create refresh failure as create failure. Replacing it mechanically can invite duplicate creation after a successful mutation and failed refetch; Cursor reported that residual risk.

**Suggested context fix:** Name the registries list-mutation default and comparable examples. Separate mutation success from refresh success, and preserve duplicate-submission protection. Unexpected missing payloads should follow the local error/reporting path. Do not generalize list refetch to normalized entity updates or preference optimism, where existing patterns differ.

**Files:** [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md), [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md).

**Evidence:** [Cursor, record 10](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/9a4d1ddb-3bdb-4298-9def-feb207de9fd6/9a4d1ddb-3bdb-4298-9def-feb207de9fd6.jsonl:10) [Cursor, record 15](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/9a4d1ddb-3bdb-4298-9def-feb207de9fd6/9a4d1ddb-3bdb-4298-9def-feb207de9fd6.jsonl:15) [Claude, record 7](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/0014aef0-0cda-4762-9f4b-c1e855c2719a.jsonl:7) [Claude, record 164](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/0014aef0-0cda-4762-9f4b-c1e855c2719a.jsonl:164)

### 30. Ownership fixture defaults solved repetition by adding confusing inference

**Status:** Conflicting approaches across sessions; no demonstrated wrong application result.

Cursor reduced repeated userId arguments by inferring the dashboard owner from a single permission user. Claude later questioned that inference, which scanned builder steps and threw for multiple users; removing it broke many existing fixtures. The user’s goal was simple, representative tests. The transcripts do not settle one universally correct builder implementation.

**Suggested context fix:** Document actor, entity owner and permission grant as separate concepts. Choose one explicit builder default/actor contract before changing many fixtures, based on the existing dependency graph. Make ownership cases explicit and reject ambiguous inference. Record the chosen builder decision once. Do not enshrine “infer ownership from permissions” or ban every default merely because one session preferred it.

**Files:** [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md).

**Evidence:** [Cursor, record 1](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/31be48f1-3a53-42cb-979a-a7a04ff072dc/31be48f1-3a53-42cb-979a-a7a04ff072dc.jsonl:1) [Cursor, record 14](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/31be48f1-3a53-42cb-979a-a7a04ff072dc/31be48f1-3a53-42cb-979a-a7a04ff072dc.jsonl:14) [Claude, record 5](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/433df48a-f01e-48bd-adb8-0e115b4cfd6b.jsonl:5) [Claude, record 83](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/433df48a-f01e-48bd-adb8-0e115b4cfd6b.jsonl:83)

### 31. PR feedback and small changes expanded into unrelated refactors

**Status:** Repeated explicit scope correction.

A test cleanup became a broad backend refactor and included frontend edits. Numeric summary acquired separate layout-permission and filter-disabling changes. Cursor interpreted “rest of the frontend” as the whole frontend and changed unrelated registry preferences and hidden-options copy. Some earlier broad work was explicitly authorized, so the issue is tracking the current requested boundary, not forbidding all useful cleanup.

**Suggested context fix:** In PR feedback, interpret “the rest” as the remaining feature diff and necessary callers unless broader scope is explicit. Before final checks, classify changed files/hunks against the requested outcome. Keep unrelated improvements as suggestions or a separately authorized PR. When the user narrows scope, remove the superseded changes and re-check the final PR diff, not only the last commit.

**Files:** [agents/AGENTS.md](/Users/philip/.config/agents/AGENTS.md), [skills.work/address-feedback/SKILL.md](/Users/philip/.config/skills.work/address-feedback/SKILL.md), [skills.work/create-pr/SKILL.md](/Users/philip/.config/skills.work/create-pr/SKILL.md), [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md).

**Evidence:** [Codex, 2026-09-08, turn 60](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-10-39-01a07d7e-8644-7781-ae77-e5ed5009732a.jsonl:1294) [Codex, 2026-09-08, turn 66](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-10-39-01a07d7e-8644-7781-ae77-e5ed5009732a.jsonl:1558) [Codex, 2026-09-07, turn 73](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T22-14-06-01a07d81-aecf-7f21-ac05-5f8f96c78137.jsonl:693) [Codex, 2026-09-09, turn 214](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T14-27-38-01a08623-5722-7742-af10-49c8d8aa9033.jsonl:204) [Codex, 2026-09-09, turn 270](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T19-59-11-01a08752-e2e1-7ec3-a395-41f69cc8cca8.jsonl:636) [Codex, 2026-09-09, turn 295](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T21-46-27-01a087b5-19cc-7ac2-a0bf-461cc24f564a.jsonl:99) [Cursor, record 58](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/9a4d1ddb-3bdb-4298-9def-feb207de9fd6/9a4d1ddb-3bdb-4298-9def-feb207de9fd6.jsonl:58) [Cursor, record 63](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/9a4d1ddb-3bdb-4298-9def-feb207de9fd6/9a4d1ddb-3bdb-4298-9def-feb207de9fd6.jsonl:63)

### 32. Splitting a PR moved required UI changes into the wrong branch

**Status:** Confirmed split error.

When animations were extracted from personal dashboards, the dashboard selector, title styling and other required UI improvements moved with them. You had to ask the agent to inspect every diff. The assistant acknowledged it had moved too much.

**Suggested context fix:** Give PR extraction an explicit before/after behavior inventory. Assign each hunk to the requested feature, prerequisite or extracted change; reconstruct both branches and compare their combined result with the original snapshot. Verify the parent independently, then the child on its new base. Keep backup refs until both comparisons pass. This is an extraction-specific addition to the existing restack workflow.

**Files:** [skills.work/restack-pr/SKILL.md](/Users/philip/.config/skills.work/restack-pr/SKILL.md), [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md).

**Evidence:** [Codex, 2026-09-11, turn 374](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:2643) [Codex, 2026-09-11, turn 376](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:2878) [Codex, 2026-09-11, turn 377](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:2899)

### 33. Base changes and squash merges made PR diffs unexpectedly large

**Status:** Repeated encountered Git issue; not always an agent-introduced defect.

PR 4523 needed inherited parent changes removed after its base changed. PR 4529 also needed its excess diff corrected. PR 4538 grew from 27 to 60 changed files when its parent was squash-merged and GitHub changed the base: that is a history-comparison effect, not new code written at that moment. Current restack instructions now explicitly handle original feature ranges and squash merges.

**Suggested context fix:** The root trigger already includes changing a PR base. Keep and apply that routing for “set master as base”; a merged-parent follow-up should use the same workflow. Verify the final diff against the actual PR base, preserving only feature commits after the old boundary. No new general rebase checklist is needed. A context change can improve handling; it cannot prevent GitHub from recalculating a stacked diff after a squash merge.

**Files:** [dev/context/ledidi-monorepo/AGENTS.md](/Users/philip/.config/dev/context/ledidi-monorepo/AGENTS.md), [skills.work/restack-pr/SKILL.md](/Users/philip/.config/skills.work/restack-pr/SKILL.md).

**Evidence:** [Codex, 2026-09-09, turn 143](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T09-35-03-01a08517-7863-7a90-a092-dc70910971de.jsonl:356) [Codex, 2026-09-09, turn 187](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T12-54-58-01a085ce-82c6-73c0-9a2c-4eeb0782bf7e.jsonl:9) [Codex, 2026-09-10, turn 328](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T08-53-55-01a08a18-2eb2-76c3-b75b-ea88ddabfb7b.jsonl:9)

### 34. Related sessions duplicated or changed each other’s work

**Status:** Confirmed overlapping PR work; concurrent activity without proven data loss.

PRs 4568 and 4560 independently included the same reader-permission change and required manual de-duplication. A Claude session also observed Cursor committing on its branch during ongoing work. The latter did not demonstrate lost work, but invalidated assumptions about the current tree. A one-writer rule exists in worktree, which ordinary edits to an existing checkout can fail to load.

**Suggested context fix:** Route the branch-ownership check from the pre-edit step, not only worktree creation/entry. Before implementing shared behavior, inspect known related feature branches/PRs that touch it and identify its owner. Record starting HEAD and re-check intervening changes before commit or evidence reuse. Context cannot provide a real lock; do not claim the rule eliminates races.

**Files:** [dev/context/ledidi-monorepo/AGENTS.md](/Users/philip/.config/dev/context/ledidi-monorepo/AGENTS.md), [skills.work/worktree/SKILL.md](/Users/philip/.config/skills.work/worktree/SKILL.md), [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md).

**Evidence:** [Cursor, record 1](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/ad684b5d-e8e2-4566-89d1-21e8c73d689a/ad684b5d-e8e2-4566-89d1-21e8c73d689a.jsonl:1) [Cursor, record 8](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/ad684b5d-e8e2-4566-89d1-21e8c73d689a/ad684b5d-e8e2-4566-89d1-21e8c73d689a.jsonl:8) [Claude, record 1175](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/bc9ba781-4278-4b83-b143-6c6b12279d2a.jsonl:1175) [Codex, 2026-09-09, turn 283](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T20-02-01-01a08755-7bc7-73a2-9281-1c9e8324f4f8.jsonl:774)

### 35. “Green” draft checks missed affected consumer suites

**Status:** Confirmed delivery gap, already addressed in context.

For PR 4459 the historical investigation found checks had passed while it was draft. After your account marked it ready, newly triggered shell E2E failed because tests still expected the removed Registry overview navigation. The agent had checked the standalone app and reported readiness without making skipped suites clear. This was not evidence that Codex marked the PR ready itself.

**Suggested context fix:** Retain the September 8/10 rules: identify affected embedded consumers, run required journeys locally when draft CI skips them, and report passed/pending/skipped separately. Keep PRs draft until you request otherwise. Do not restore automatic CI monitoring for every push; use finish-pr only when requested. The current wording already addresses this incident.

**Files:** [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md), [skills.work/finish-pr/SKILL.md](/Users/philip/.config/skills.work/finish-pr/SKILL.md).

**Evidence:** [Codex, 2026-09-08, turn 76](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T08-35-16-01a07fba-6279-7261-8cba-4ff8fb010a5f.jsonl:9) [Codex, 2026-09-08, turn 80](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T08-36-07-01a07fbb-2908-7262-9522-cbd303d68c77.jsonl:9)

### 36. Small follow-up edits reran thousands of unrelated tests

**Status:** Confirmed time cost, largely addressed September 10.

One test-readability edit ran 3,017 backend and 1,170 frontend tests, then hooks ran more checks. The first backend attempt used seven workers and hit timeouts; another run used two. Similar chart work waited on broad backend checks. You explicitly requested a session analysis and implemented narrower verification afterward.

**Suggested context fix:** Keep current follow-up versus branch scope, evidence reuse, hook equivalence and database-concurrency rules. Do not add an automatic browser/full-suite/review requirement to every fix in this report. If a check broadens, require the changed input or unresolved concern that makes the wider run necessary. There is no clear evidence here that the same excessive-run policy persisted after the September 10 fix.

**Files:** [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md), [skills.work/dev-stack/SKILL.md](/Users/philip/.config/skills.work/dev-stack/SKILL.md).

**Evidence:** [Codex, 2026-09-09, turn 180](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T12-14-04-01a085a9-0fd5-70e1-8125-941bd990ff3d.jsonl:390) [Codex, 2026-09-10, turn 318](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-37-38-01a089d2-55f7-77e1-9480-65d182a63c85.jsonl:381) [Codex, 2026-09-10, turn 319](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T08-02-05-01a089e8-b9df-79d1-94e2-428f28dbbaa6.jsonl:9) [Codex, 2026-09-10, turn 320](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T08-02-05-01a089e8-b9df-79d1-94e2-428f28dbbaa6.jsonl:57)

### 37. Browser checks used the wrong API and stale backend images; stack startup also had a script bug

**Status:** Confirmed environment failures; distinguish context from tooling.

One E2E command set the frontend API URL but omitted E2E_API_URL, so fixtures called a default port. A rebased worktree mounted the new Prisma directory while its image kept the old prisma.config.ts. Separately dev stack up -d dropped service selection and started all enabled services even though the agent had loaded the current skill. That third failure was a script defect, not an instruction-following failure.

**Suggested context fix:** Keep dev test e2e as the worktree-aware entry point and the existing image-refresh guidance after schema/build changes. Keep the evidence-based three-stack capacity policy. No context-only rewrite can repair dropped shell arguments; the September 7 script fix was required and is already present. Treat seed count/API mismatches as completion evidence to check, not a reason to patch product code blindly.

**Files:** [skills.work/dev-stack/SKILL.md](/Users/philip/.config/skills.work/dev-stack/SKILL.md), [skills.work/seed-registry/SKILL.md](/Users/philip/.config/skills.work/seed-registry/SKILL.md).

**Evidence:** [Codex, 2026-09-07, turn 49](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T21-43-41-01a07d65-d61c-7fb3-9f4a-ae151c51c687.jsonl:9) [Codex, 2026-09-08, turn 94](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T17-17-37-01a08198-9bed-7ab0-8f68-33c0b4b1c3e0.jsonl:9) [Codex, 2026-09-08, turn 97](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T17-17-37-01a08198-9bed-7ab0-8f68-33c0b4b1c3e0.jsonl:189)

### 38. Harnesses loaded duplicate instructions, and skills lacked consistent metadata

**Status:** Confirmed tooling/context friction, already addressed.

Cursor loaded both full rendered AGENTS.md and CLAUDE.local.md. Skill names/display metadata differed, and show-stories initially lacked openai.yaml. You also had to request propagation to all worktrees. The current repository has the pointer, shared metadata requirement and mandatory render/check rules.

**Suggested context fix:** Keep one shared source with harness-specific pointers and consistent metadata. Verify all registered checkouts after actual context changes. Do not add another copy of the policy. This analysis does not establish that missing rules were caused by a particular harness’s automatic-loading behavior; the reliable evidence is the local duplication and its recorded fix.

**Files:** [AGENTS.md](/Users/philip/.config/AGENTS.md), [dev/context/ledidi-monorepo/CLAUDE.local.md](/Users/philip/.config/dev/context/ledidi-monorepo/CLAUDE.local.md), [install-common.sh](/Users/philip/.config/install-common.sh).

**Evidence:** [Cursor, record 3](/Users/philip/.cursor/projects/Users-philip-work-ledidi-monorepo/agent-transcripts/793c7ba2-9c83-4a88-8989-3e7e1fcfa4b1/793c7ba2-9c83-4a88-8989-3e7e1fcfa4b1.jsonl:3) [Cursor, record 1](/Users/philip/.cursor/projects/Users-philip-config/agent-transcripts/0894fe61-de4a-41d7-aa5d-02825dcb1835/0894fe61-de4a-41d7-aa5d-02825dcb1835.jsonl:1) [Codex, 2026-09-09, turn 156](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T11-46-33-01a0858f-dde7-7501-94d0-1ff8789c0fcc.jsonl:9) [Codex, 2026-09-09, turn 193](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T13-31-29-01a085ef-f004-79f3-9bf6-d7c0021bb17b.jsonl:135) [Codex, 2026-09-09, turn 194](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T13-31-29-01a085ef-f004-79f3-9bf6-d7c0021bb17b.jsonl:145) [Codex, 2026-09-10, turn 326](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T08-02-05-01a089e8-b9df-79d1-94e2-428f28dbbaa6.jsonl:394) [Codex, 2026-09-10, turn 327](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T08-02-05-01a089e8-b9df-79d1-94e2-428f28dbbaa6.jsonl:423)

### 39. Review can target the wrong revision, and existing guidance does not explicitly capture uncommitted implementation

**Status:** Documented workflow gap; causal link to escaped defects is unproven.

The history contains a stale-version explanation, and one review correctly had to capture uncommitted UI work. Independently, current create-pr invokes review before committing, while code-review pins a base and HEAD three-dot diff and can report no changes on an empty committed diff. verify-change includes working-tree changes, but the review instructions do not explicitly do so. The conversations do not prove this gap caused every missed issue.

**Suggested context fix:** Support an immutable snapshot including task-owned staged, unstaged and untracked changes in code-review, with the known task/PR base supplied by its caller. Verify that the reviewed snapshot matches the final implementation after fixes. Keep findings tied to that revision and distinguish observed defects from speculative design concerns. This improves review scope without requiring more review passes for small edits.

**Files:** [skills/code-review/SKILL.md](/Users/philip/.config/skills/code-review/SKILL.md), [skills.work/create-pr/SKILL.md](/Users/philip/.config/skills.work/create-pr/SKILL.md), [skills.work/verify-change/SKILL.md](/Users/philip/.config/skills.work/verify-change/SKILL.md).

**Evidence:** [Codex, 2026-09-09, turn 208](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T14-27-38-01a08623-5722-7742-af10-49c8d8aa9033.jsonl:77) [Codex, 2026-09-11, turn 367](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:1502) [Claude, record 362](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/007d34b3-7e6c-42d3-816d-091bfad54810.jsonl:362)

### 40. Grilling repeatedly asked several questions after you requested one at a time

**Status:** Direct preference conflict in the current skill.

You repeatedly asked for one question at a time. The current grilling skill tells the agent to ask the whole available frontier in each round. That instruction actively pushes the opposite pacing unless your correction remains salient in the conversation.

**Suggested context fix:** Change grilling to one question at a time by default, or explicitly persist the user’s chosen pace for the rest of the session. Keep independent factual investigation in the background. An agreed design answer settles that question; retain the separate implementation-authorization rule.

**Files:** [skills/grilling/SKILL.md](/Users/philip/.config/skills/grilling/SKILL.md).

**Evidence:** [Codex, 2026-09-07, turn 23](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T11-49-48-01a07b46-1e31-71a0-a741-7ec6c5042d65.jsonl:464) [Codex, 2026-09-07, turn 34](/Users/philip/.codex/sessions/2026/09/07/rollout-2026-09-07T11-49-48-01a07b46-1e31-71a0-a741-7ec6c5042d65.jsonl:1856) [Codex, 2026-09-10, turn 353](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T18-05-57-01a08c11-9548-77a2-aa49-8dfc3fa9244a.jsonl:127)

### 41. Explanations, review reports, completion and roadmap updates required extra prompting

**Status:** Observed communication/workflow friction; most fixes already exist.

You asked what “patient-mode” meant, needed full report paths, requested matching Claude/Codex report formats and copyable findings, and repeatedly prompted commits before the default changed. Some GraphQL comments created formatting noise. Kaplan–Meier’s story-map status also needed updating. These should not be mixed with runtime code defects, but they increased review effort.

**Suggested context fix:** Keep the existing plain-language, concrete-name, clickable-path, commit-default and shared-report rules. Require current story-map status when delivering the corresponding feature; no new universal tracker is needed. Remove code comments that only restate obvious code, while retaining hidden constraints. Avoid duplicating report-format rules now enforced by the shared template. Resolve codebase-design’s demand to replace service/component/API vocabulary with the global requirement to use the repository’s terms.

**Files:** [agents/AGENTS.md](/Users/philip/.config/agents/AGENTS.md), [skills.work/review-pr/references/delivery.md](/Users/philip/.config/skills.work/review-pr/references/delivery.md), [skills.work/create-pr/SKILL.md](/Users/philip/.config/skills.work/create-pr/SKILL.md), [skills/codebase-design/SKILL.md](/Users/philip/.config/skills/codebase-design/SKILL.md).

**Evidence:** [Codex, 2026-09-09, turn 158](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T11-46-33-01a0858f-dde7-7501-94d0-1ff8789c0fcc.jsonl:89) [Codex, 2026-09-09, turn 163](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T12-08-12-01a085a3-b17c-72b3-9f69-ab531a24a6ac.jsonl:63) [Codex, 2026-09-09, turn 164](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T12-08-12-01a085a3-b17c-72b3-9f69-ab531a24a6ac.jsonl:97) [Codex, 2026-09-09, turn 167](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T12-08-12-01a085a3-b17c-72b3-9f69-ab531a24a6ac.jsonl:263) [Codex, 2026-09-09, turn 193](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T13-31-29-01a085ef-f004-79f3-9bf6-d7c0021bb17b.jsonl:135) [Codex, 2026-09-09, turn 269](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T19-59-11-01a08752-e2e1-7ec3-a395-41f69cc8cca8.jsonl:603) [Codex, 2026-09-09, turn 290](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T21-46-27-01a087b5-19cc-7ac2-a0bf-461cc24f564a.jsonl:34) [Codex, 2026-09-11, turn 383](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T08-51-38-01a08f3c-7261-7a12-805e-809d64f2d6a1.jsonl:794) [Codex, 2026-09-11, turn 411](/Users/philip/.codex/sessions/2026/09/11/rollout-2026-09-11T14-46-22-01a09081-36e4-7180-93ec-afdd5537d8ce.jsonl:86) [Claude, record 197](/Users/philip/.claude/projects/-Users-philip-work-ledidi-monorepo/0014aef0-0cda-4762-9f4b-c1e855c2719a.jsonl:197)

### 42. Specific failure reasons were lost, and stale filter types needed explicit handling

**Status:** Confirmed error-handling defects and requested improvements.

runAnalysis dropped specific subcodes into UNBUILDABLE, while the generic card message blamed the counted variable even when grouping or filters failed. createAnalysis also replaced a known type mismatch with a generic error. Later feedback fixed stale LINEAR_SCALE filters while preserving genuine internal faults and keeping other cards usable. Clear user errors and safe internal errors have different contracts.

**Suggested context fix:** Trace each recoverable analysis failure from validation through result/GraphQL mapping to translated UI copy. Preserve actionable reason codes and the actual input role; test save and run where their error contracts differ. Keep internal faults distinct, without leaking answer values or treating every unexpected failure as an ordinary unbuildable card. A failed card must not prevent independent cards from loading. The analytics reference already states accurate errors; make the layer trace part of completion.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/references/frontend.md](/Users/philip/.config/skills.work/coding-standards/references/frontend.md).

**Evidence:** [Codex, 2026-09-09, turn 147](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T11-17-04-01a08574-e081-7793-9620-27c7c0ac06b7.jsonl:9) [Codex, 2026-09-10, turn 302](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T07-06-24-01a089b5-bde2-7af0-a88f-15bb1cc19a53.jsonl:375) [Codex, 2026-09-10, turn 349](/Users/philip/.codex/sessions/2026/09/10/rollout-2026-09-10T13-10-41-01a08b03-4196-7b22-9c7f-25cbbb1d3861.jsonl:9)

### 43. Category ordering, zero groups and missing-value identities were inconsistent

**Status:** Confirmed defects and an explicit default decision.

The variable selector did not follow registry design ordering. Available chart categories changed with real/training data, and grouping dictionaries omitted unused groups because they depended on answered versions. A tooltip used the same missing key for a missing grouping value and a missing counted value, producing the wrong heading. Numeric summary also skipped invalid-group validation when its measurement was missing. Later zero-only empty-card behavior changed separately.

**Suggested context fix:** Record the agreed category contract: current design order and zero categories for comparison, historical answered options retained under the scoped population, and explicit ordering for historical/missing entries. Keep group identity distinct from counted-value/series identity even when both display Missing. Test their simultaneous presence and stable option-ID mapping. Keep option-dictionary construction, calculation and display ordering with their agreed owners rather than scattering fixes across chart kinds.

**Files:** [skills.work/coding-standards/references/registry-analytics.md](/Users/philip/.config/skills.work/coding-standards/references/registry-analytics.md), [skills.work/coding-standards/references/testing.md](/Users/philip/.config/skills.work/coding-standards/references/testing.md).

**Evidence:** [Codex, 2026-09-08, turn 82](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T12-06-30-01a0807b-c77a-79e0-b412-cfbbf3b8c989.jsonl:9) [Codex, 2026-09-09, turn 104](/Users/philip/.codex/sessions/2026/09/08/rollout-2026-09-08T21-40-32-01a08289-50aa-7873-ad08-c19ca9430510.jsonl:480) [Codex, 2026-09-09, turn 107](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T07-45-15-01a084b2-f2c8-7e92-adbe-57231f687051.jsonl:9) [Codex, 2026-09-09, turn 110](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T07-45-15-01a084b2-f2c8-7e92-adbe-57231f687051.jsonl:154) [Codex, 2026-09-09, turn 136](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T08-37-40-01a084e2-f068-7b53-9f99-429e73cb9f09.jsonl:705) [Codex, 2026-09-09, turn 266](/Users/philip/.codex/sessions/2026/09/09/rollout-2026-09-09T19-59-11-01a08752-e2e1-7ec3-a395-41f69cc8cca8.jsonl:185)

### 44. A root tooling change never produced the required PR check

**Status:** Confirmed CI configuration gap; repair required monorepo code.

PR 4398 changed lefthook.yml, but no workflow produced pr-checks for the commit. The conversation confirmed that the Docs & Scripts path filter omitted lefthook.yml. Adding that path started the missing job and made the draft green. This was a missing run, distinct from a failing test or a draft-skipped E2E suite.

**Suggested context fix:** When changing root tooling, shared generation or CI inputs, identify which workflow produces the required aggregate check and whether its path conditions include the changed file. Classify a missing check separately from pending execution before monitoring. This context can prevent recurrence during implementation; the historical repair itself needed a workflow edit in the monorepo and cannot be accomplished by context alone.

**Files:** [skills.work/coding-standards/references/infrastructure.md](/Users/philip/.config/skills.work/coding-standards/references/infrastructure.md), [skills.work/finish-pr/SKILL.md](/Users/philip/.config/skills.work/finish-pr/SKILL.md).

**Evidence:** [Codex, 2026-09-06, turn 12](/Users/philip/.codex/sessions/2026/09/06/rollout-2026-09-06T07-52-22-01a07546-6335-7dc0-a14c-7003f25b75f0.jsonl:9)

## Decisions that should not become blanket prohibitions

| Conversation topic | What the evidence supports |
| --- | --- |
| Current versus historical event options; NUMBER-only duration | The original Kaplan–Meier spec required the narrower behavior. Historical-option support changed later. Update the authoritative decision rather than describing all original guards as mistakes. |
| Display switches stored on the analysis definition | The approved spec explicitly chose this. Questioning the location did not establish a defect. |
| Curves with different visual appearance | One assessment found the same path generator and width for grouped and ungrouped results; a perceptual difference needed a controlled comparison. |
| Shared frequency-result fixture | It had eight consumers. A separate helper was justified; the question was not evidence of premature abstraction. |
| GraphQL resolver tests | They prove real input/output mapping that application tests cannot prove. Reduce repeated arithmetic, not the transport contract. |
| A fixture called “retired” | The name alone did not prove retirement, but real retirement was covered in a reader integration test. Rename the misleading test rather than inventing a missing-behavior claim. |
| Non-numeric string coverage | The requested NOT_A_NUMBER case had an equivalent unparseable “12,5” case already. NaN/Infinity cases covered a different problem. |
| A Chromatic screenshot of a short error card | One later apparent crop was scrollable and accessible. Do not equate an initial screenshot with inaccessible content. |
| At-risk table and legend placement | Preferences changed on September 12–13, including hiding the legend when colored table rows are visible. Keep the latest decision, not every intermediate instruction. |
| Numeric validation against R and Python | Requested comparison produced an existing 36-scenario report. The later inspection reused it because the computation was unchanged. This is useful numerical evidence, not proof an earlier arithmetic result was wrong. |
| Registry ownership/RLS questions | The inspected ownership policy was consistent; naming, builder semantics and comments needed improvement. No data leak was demonstrated. |

## Additional observations with weaker evidence

These are worth retaining, but are not counted as user-reproduced defects.

- Cursor seeding runs reported 20 ankle patients requested but 18 visible, a PROM API mismatch, and a TypeScript overlay after seeding. The reason for the count mismatch was speculative. A completion check should compare requested and persisted fixtures and identify the target API before claiming success. Existing uncommitted seed-registry work already adds an analysis fixture roster; do not add it again.
- A Claude review of PR 4041 reported a stale PR description, repeat-visit send-out deduplication, a hint leading to an unsuitable page, and missing READY/old-event cases. These are historical review candidates, not independently confirmed symptoms. Existing scope, identity and test rules largely cover the suggested lessons.
- The same-branch rule is guidance, not an enforced lock. Local histories show overlapping writers, but do not establish that every subsequent defect came from concurrency.
- The HEAD-only review mismatch is visible in the current workflow files. The available history does not prove how frequently agents followed that exact comparison or how many defects escaped because of it.

## Context fixes already made during the week

| Date | Commit | What already changed |
| --- | --- | --- |
| September 6 | f211405 | Broad standards, local/nested context discovery and affected-consumer guidance from the older PR audit. |
| September 7 | 6f614c5 | Stack script preserves service selection with flags such as -d. |
| September 8 | d9695d7 | Readable scenario tests, existing builders, affected local E2E for draft skips, skipped-check reporting and no risk label in titles. |
| September 8 | 1cd1762, 545af7f | Correct worktree E2E APIs, stale image refresh and three-stack capacity handling. |
| September 9 | 68c0a9d, 45b81f0 | Commit completed work by default; three real cases before introducing shared abstraction. |
| September 9 | 20c2087, 56e461a | Skill metadata requirements and show-stories workflow. |
| September 9 | e51e501, 361cdd6, 19b53fa | Consistent review reports, copyable findings and severity filters. |
| September 10 | 54b7bd3 | Follow-up verification scope, evidence reuse, selective independent review, no automatic CI monitoring and concurrency guidance. |
| September 10 | 854edec, 3e5f26e | Worktree E2E CORS fix and mandatory all-worktree context rendering/checking. |
| September 12 | f596d02 | CLAUDE.local.md points to the shared AGENTS.md instead of duplicating it. |

These commit IDs resolve in this repository’s Git history. Their presence proves the instruction or script changed; it does not prove every later session loaded it or followed it. The existing September 5 audit and current owner files explain the protections in more detail.

## How to keep the update small

Prefer one domain-specific analysis reference, a small set of concrete examples in existing standards, and targeted rewrites of conflicting rules. Avoid a new universal checklist per incident. Keep semantic contracts in the domain reference and execution steps in their owning skills. The proposed reference is new; the files listed in the inventory are its existing routing/ownership locations.

If these suggestions are implemented, evaluate the changed guidance on a few real scenarios from this report: a new analysis kind, a dashboard loading fix, a test-readability change and a stacked-PR split. Check whether the agent selects the right owner, keeps scope, and produces evidence for the actual behavior. A rule that merely becomes longer without changing those choices has not solved the problem.

Pre-existing work was preserved in dev/lib/cli.sh, dev/stack.sh and skills.work/seed-registry/{SKILL.md,agents/openai.yaml}. No product tests were run because this task changed no product behavior. The report’s local evidence links and referenced context paths were checked for existence.
