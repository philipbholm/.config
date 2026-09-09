# Review delivery

Report mode produces HTML. In post mode, generate an additional HTML report
only when the user asks for one. Reuse the same finding text in either output
and in the report's copy controls.

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

### Severity filters

Above the findings, add labeled checkboxes for Critical, Major, and Minor,
plus “Critical + Major” and “Show all” buttons. Select all severities initially.
Use inline JavaScript to filter finding cards across every report section.
The controls must support keyboard use and expose their selected state.

Show the visible finding count alongside the total. Hide section headings when
all their content is filtered out, and show “No findings match the selected
severities” when no cards match. Keep the verdict and overall severity and pass
counts unchanged. Keep unclassified content, including Needs investigation and
Unchecked notes, visible outside the severity filter.

Include every finding in the HTML. Without JavaScript, show the full report and
hide the filter controls. Before opening the report, verify that Critical +
Major hides Minor cards, individual checkboxes work, Show all restores every
card, and an empty selection shows the no-match message.

### Copy findings as quotes

Give every finding card a keyboard-accessible “Copy quote” button. Copy plain
text containing a GitHub Markdown blockquote, ready to paste into a PR comment.
Include the finding's title, severity or investigation status, pass labels,
file and line permalink when available, evidence, consequence, and suggested
correction. Preserve paragraphs, lists, inline code, and fenced code blocks;
prefix every line, including blank lines and code fences, with `> `.

Build the quote from the same finding content used to render the card, rather
than copying the card's rendered text or HTML. Exclude buttons and other report
controls. Preserve literal code characters and URLs through HTML escaping so
the clipboard contains the original Markdown rather than HTML entities.

Show “Copied” only after the clipboard write succeeds and announce the result
to assistive technology. Provide an expandable “Quote Markdown” field with
selectable, read-only text for manual copying, including when JavaScript is
disabled or clipboard access fails from a local HTML file.

Before delivery, check a copied quote containing multiple paragraphs, a link,
and a fenced code sample with `<`, `>`, and `&`. Verify that the Markdown keeps
the entire finding inside one blockquote and that manual copying also works.

After checking the filters and copy controls, open the HTML file with `open`
and return its absolute path.

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
