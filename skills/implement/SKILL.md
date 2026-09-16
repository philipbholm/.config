---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

In Ledidi, load `verify-change` to select and reuse checks and `coding-standards`
to select self-review or independent review. Elsewhere, follow the repository's
verification and review requirements. Run focused checks while editing and
cover the final diff before committing; repeat passing checks only when their
inputs change.

Commit your work to the current branch.
