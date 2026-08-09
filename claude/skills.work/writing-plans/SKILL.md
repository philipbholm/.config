---
name: writing-plans
description: Use when turning an agreed spec or set of requirements into a written implementation plan for a multi-step change, before touching code. Skip when the change is small enough to just make.
---

# Writing Plans

## Overview

Write the plan for an engineer who has zero context for this codebase. Document
what they need: which files to touch for each task, the actual code, the tests,
docs worth checking, how to verify it. Assume they are skilled but know almost
nothing about our toolset or problem domain, and don't know good test design
very well. DRY. YAGNI. TDD. Frequent commits.

**Save plans to:** `docs/plans/YYYY-MM-DD-<feature-name>.md`, relative to the
current project (project instructions override this location).

## Scope Check

If the spec covers multiple independent subsystems, suggest breaking it into
separate plans — one per subsystem. Each plan should produce working, testable
software on its own.

## File Structure

Before defining tasks, map out which files will be created or modified and what
each one is responsible for. This is where decomposition decisions get locked
in.

- Design units with clear boundaries and well-defined interfaces. Each file
  should have one clear responsibility.
- You reason best about code you can hold in context at once, and your edits are
  more reliable when files are focused. Prefer smaller, focused files over large
  ones that do too much.
- Files that change together should live together. Split by responsibility, not
  by technical layer.
- In existing codebases, follow established patterns. If the codebase uses large
  files, don't unilaterally restructure — but if a file you're modifying has
  grown unwieldy, including a split in the plan is reasonable.

This structure informs the task decomposition. Each task should produce
self-contained changes that make sense independently.

## Task Right-Sizing

A task is the smallest unit that carries its own test cycle and is worth a fresh
reviewer's gate. When drawing task boundaries: fold setup, configuration,
scaffolding, and documentation steps into the task whose deliverable needs them;
split only where a reviewer could meaningfully reject one task while approving
its neighbor. Each task ends with an independently testable deliverable.

A task is the unit of work, not a single tool call. Give the whole task
specification up front — the failing test, the implementation, the verification
command, the commit — and let the implementer run it end to end. Keep the
checkbox (`- [ ]`) syntax so progress stays trackable.

## Plan Document Header

Every plan starts with this header:

```markdown
# [Feature Name] Implementation Plan

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about approach]

**Tech Stack:** [Key technologies/libraries]

## Global Constraints

[The spec's project-wide requirements — version floors, dependency limits,
naming and copy rules, platform requirements — one line each, with exact
values copied verbatim from the spec. Every task's requirements implicitly
include this section.]

---
```

## Task Structure

````markdown
### Task N: [Component Name]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks — exact signatures]
- Produces: [what later tasks rely on — exact function names, parameter
  and return types, so the signatures line up across tasks.]

- [ ] **Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

Run: `pytest tests/path/test.py::test_name -v` — expect FAIL with
"function not defined".

- [ ] **Implement**

```python
def function(input):
    return expected
```

Run: `pytest tests/path/test.py::test_name -v` — expect PASS.

- [ ] **Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
````

## No Placeholders

Every step must contain the actual content an engineer needs. These are **plan
failures** — never write them:

- "TBD", "TODO", "implement later", "fill in details"
- "Add appropriate error handling" / "add validation" / "handle edge cases"
- "Write tests for the above" (without actual test code)
- "Similar to Task N" without naming what differs (say which parts change;
  cross-referencing an earlier task's code is fine)
- Steps that describe what to do without showing how (code blocks required for
  code steps)
- References to types, functions, or methods not defined in any task

Names and types must line up across tasks. A function called `clearLayers()` in
Task 3 and `clearFullLayers()` in Task 7 is a bug in the plan.

## After Saving

Tell the user where the plan landed and what the first task does. Executing it
is a separate decision — don't start implementing unless asked.
