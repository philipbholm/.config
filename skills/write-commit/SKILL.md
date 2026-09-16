---
name: write-commit
description: Write commit messages when creating or amending commits, drafting a message, or reviewing commit-message style.
---

# Write a commit message

For Registries work in `ledidi-as/ledidi-monorepo`, read
[Work pull requests](../write-pr/references/work.md) and use its SDLC commit
format. That format overrides the plain-title rule below. Apply the prose
rules here to its description and optional body.

Use the plain-title style below in other repositories.

Write the title in imperative mood and sentence case, for example
`Skip unrelated checks after rebasing`. Start with a concrete verb, capitalise
the first word, and omit prefixes, scopes, emoji and the trailing period.

The body is optional. Add it when the title leaves useful context unexplained.
Use as many sentences as needed, but keep the explanation as concise as
reasonable. Explain the reason or a consequence the reader needs to know;
omit a recap of the diff. Separate the body from the title with a blank line.

Message style does not authorize a commit or a push. Follow the repository's
verification instructions before either action.
