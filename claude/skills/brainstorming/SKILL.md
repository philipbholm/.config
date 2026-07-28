---
name: brainstorming
description: Use before building a feature or changing behavior where the requirements are not yet settled — turns an idea into an agreed design. Skip for changes with one obvious reading.
---

# Brainstorming Ideas Into Designs

Turn an idea into a design through collaborative dialogue: understand the
project context, ask what you don't know, propose approaches, agree on one, and
write it down.

Scale the design to the change. A one-line config edit does not need a design
document; a new subsystem does. If every reasonable reading of the request leads
to the same work, skip this and go build it. The cycle earns its keep when
different readings would produce materially different software.

## The Process

**Understand the idea.**

- Check the current project state first — files, docs, recent commits.
- Assess scope before asking detailed questions. If the request describes
  several independent subsystems ("a platform with chat, file storage, billing,
  and analytics"), say so immediately rather than refining details of something
  that needs decomposing. Help split it into sub-projects: what the independent
  pieces are, how they relate, what order to build them. Then brainstorm the
  first one through the normal flow — each sub-project gets its own spec, plan,
  and implementation cycle.
- For appropriately-scoped work, ask questions one at a time. Only one question
  per message; if a topic needs more exploration, break it into several.
- Use `AskUserQuestion` whenever the question has discrete options — it handles
  multi-select and previews natively. Keep plain prose for open-ended
  exploration where you'd be inventing the options.
- Focus on purpose, constraints, and success criteria.

**Explore approaches.**

- Propose 2–3 approaches with trade-offs.
- Lead with your recommendation and explain why.
- YAGNI ruthlessly — strip unnecessary features out of every approach.

**Present the design.**

- Once you understand what you're building, present it.
- Scale each section to its complexity: a few sentences if straightforward, up
  to 200–300 words if nuanced.
- Ask after each section whether it looks right so far.
- Cover architecture, components, data flow, error handling, testing.
- Be ready to go back and clarify if something doesn't make sense.

**Design for isolation and clarity.**

- Break the system into smaller units that each have one clear purpose,
  communicate through well-defined interfaces, and can be understood and tested
  independently.
- For each unit, you should be able to answer: what does it do, how do you use
  it, what does it depend on?
- Can someone understand what a unit does without reading its internals? Can you
  change the internals without breaking consumers? If not, the boundaries need
  work.
- Smaller, well-bounded units are also easier to work with — you reason better
  about code you can hold in context at once, and edits are more reliable when
  files are focused. A file growing large is often a signal it's doing too much.

**Working in existing codebases.**

- Explore the current structure before proposing changes. Follow existing
  patterns.
- Where existing code has problems that affect the work — a file that's grown
  too large, unclear boundaries, tangled responsibilities — include targeted
  improvements in the design, the way a good developer improves code they're
  working in.
- Don't propose unrelated refactoring. Stay focused on what serves the current
  goal.

## After the Design

Write the validated design to `docs/specs/YYYY-MM-DD-<topic>-design.md` (project
instructions override this location) and commit it.

Then ask the user to review the written spec:

> "Spec written and committed to `<path>`. Have a look and let me know if you
> want anything changed before I write the implementation plan."

If they request changes, make them and ask again. Once they approve,
`writing-plans` is the usual next step.

## Before Implementation

Present a design and get agreement before writing code or scaffolding a
project. The design can be three sentences for something small — the point is
that the shape of the work is agreed, not that a document exists.
