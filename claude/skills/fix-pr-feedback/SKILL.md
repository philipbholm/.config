---
name: fix-pr-feedback
description: Use when addressing reviewer feedback left on a GitHub pull request
argument-hint: "[pr number | branch]"
---

When executing this skill create a temporary directory /tmp/claude/${session-id}/pr-feedback-checklist.md and copy the steps below, then iterate and cross of each item until done. If more than 3 total failures, ask for help

- [ ] If you have no memory of what PR it is, or if there is no open PR for the current branch, ask what github PR # is in question. If I give you a branch name assume it is the PR for that branch
- [ ] Read all github feedback,
- [ ] For each feedback, read the and fully understand the code related to that line of code
- [ ] make a list with what to fix and what is not relevant
- [ ] Be critical of feedback, dont just blindly implement it, consider if it makes sense. Read the code to get the full picture if needed
- [ ] Comment on everything that is not relevant why it is not relevant. Don't just assume something is intentional, make the argument for why it is implemented the way it is.
- [ ] Implement fixes
- [ ] Resolve fixed comments only if the reviewer is not human. If you are in doubt, do not resolve
- [ ] Ask for what to do with unclear comments
