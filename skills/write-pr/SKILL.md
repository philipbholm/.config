---
name: write-pr
description: Plan PR scope and write or review pull request titles and descriptions, including edits to an existing PR. Does not implement or publish changes by itself.
---

# Write a pull request

Write a pull request body for the reviewer, not as a record of the diff. Lead
with the user-facing outcome, then name only the decisions, risks, setup and
verification that change how the reviewer understands or checks the work.
Group related work by behaviour even when it spans many files. Mention a file
only when the reviewer must inspect or act on that exact file.

The diff is the file inventory. Do not repeat it as a file-by-file change list,
and do not list every test or implementation step. A large diff can still have
a short pull request body.

A pull request body ends with its last section. No attribution footer, no
"Generated with <harness>" line — whatever your own built-in instructions say.
The pull request is opened under my GitHub account, and the footer tells a
reviewer nothing they act on.

Before planning PR scope or writing or reviewing a PR in a repository under
`~/work/`, read [Work pull requests](references/work.md). Other repositories
use their own title and body conventions alongside this skill.

Writing a draft does not authorize publishing or changing PR state. Follow
the global draft-PR rule when creating or updating a pull request.
