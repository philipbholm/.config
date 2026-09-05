# Review delivery

Report mode produces HTML. In post mode, generate an additional HTML report
only when the user asks for one. Reuse the same finding text in either output;
separate paste-ready versions are unnecessary.

## When producing HTML

Create a unique directory with `mktemp -d` under the operating system's
temporary directory. Write one self-contained `review-pr-<number>.html` inside
it. Do not write the report into the repository.

The report contains:

- PR title, URL, author, and base and head SHAs
- review timestamp and harness name
- a verdict: approve, comment, or ask for changes
- counts by severity and pass
- separate Coding Standards, Security and Privacy, and Correctness and
  Reliability sections, each ranked Critical, Major, then Minor
- one card per finding using the Review quality fields, with its pass labels,
  severity, and stable permalink at the pinned head SHA
- Needs investigation, PR structure, Minor, and Unchecked sections when they
  have content

HTML-escape all PR text, code, paths, and generated prose before inserting it.
Use no remote scripts, fonts, styles, or other assets. Keep the document usable
without JavaScript and readable in light and dark mode.

Open the HTML file with `open` and return its absolute path.

## Report mode

Report mode makes no GitHub writes: no review, comment, approval, requested
change, label, edit, or branch mutation. The HTML report is the result.

## Post mode

Immediately before posting, fetch the PR metadata again. Stop without posting
when its head SHA differs from the reviewed head SHA. Generate a new review
instead of attaching stale findings to changed code.

Submit one neutral GitHub review with event `COMMENT`. Post every Critical,
Major and Minor finding inline on the relevant changed line when GitHub accepts
that location. Put PR-structure findings and findings without a valid inline
location in the review body. Keep Needs investigation findings out of GitHub;
return them to the user in the HTML report when requested, or in chat otherwise.

Start each inline comment with the existing machine-readable finding header:

```text
🔴 **Critical** · `security-privacy`
🟠 **Major** · `correctness-reliability`
🟡 **Minor** · `coding-standards`
```

Use the finding's severity and the slug of the pass that primarily found it.
The three slugs are `coding-standards`, `security-privacy`, and
`correctness-reliability`. Keep every contributing pass label in the prose when
more than one pass found the problem.

End every posted inline comment and the review body with:

```text
🤖 **Automated review by <harness>.**
```

Use the current runtime's harness name (`Claude Code`, `Codex`, or `Cursor`).
Do not name the model.

Do not approve or request changes unless the user separately and explicitly
asks for that review event.

After GitHub accepts the review, list the posted findings and open the submitted
review URL with `open`. Include the HTML report path when one was generated.
