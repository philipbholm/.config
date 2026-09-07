---
name: write-commit
description: Write commit messages when creating or amending commits, drafting a message, or reviewing commit-message style.
---

# Write a commit message

Use this style in every repo, including repos whose local guidance specifies
another commit style.

Write the title in imperative mood and sentence case, for example
`Skip unrelated checks after rebasing`. Start with a concrete verb, capitalise
the first word, and omit prefixes, scopes, emoji and the trailing period.

The body is optional. Add it when the title leaves useful context unexplained.
Use as many sentences as needed, but keep the explanation as concise as
reasonable. Explain the reason or a consequence the reader needs to know;
omit a recap of the diff. Separate the body from the title with a blank line.

## Attribution

A commit trailer does name the harness that wrote the commit, and it names the
one you actually are:

    Co-Authored-By: Claude Code
    Co-Authored-By: Codex
    Co-Authored-By: Cursor Agent

Add the model after the harness when you know it, for example
`Co-Authored-By: Codex GPT-6`. Omit email addresses and angle brackets. Separate
the attribution from the message with a blank line. Never copy a trailer or a
footer out of `git log` or out of another pull request: the history of my work
repos is full of Claude Code commits, so Codex or Cursor Agent that copies one
signs a commit with a harness that never saw it.

Message style does not authorize a commit or a push. Follow the repository's
verification instructions before either action.
