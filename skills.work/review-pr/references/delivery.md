# Review delivery

Report mode produces HTML. In post mode, generate an additional HTML report
only when the user asks for one. Reuse the same finding text in either output
and in the report's copy controls.

## When producing HTML

Create a unique directory with `mktemp -d` under the operating system's
temporary directory. Write one self-contained `review-pr-<number>.html` inside
it. Do not write the report into the repository.

Use [the report template](../assets/report.html) and
[the finding card template](../assets/finding.html) for every harness. Preserve
their layout, CSS, and JavaScript; fill the content slots as described below.
The templates own presentation and control behavior.

### Populate the templates

Replace `{{name}}` slots in one pass so inserted content is never interpreted
as another slot. HTML-escape text and attribute values, including quote
Markdown. Slots ending in `_html` receive generated markup whose text and
attributes have already been escaped. Keep code in `<code>` or `<pre><code>`
and links as anchors. Use no remote assets.

The report follows this order:

1. PR title and link; harness, author, review timestamp, and diff size.
2. A prominent verdict: approve, comment, or ask for changes. Follow it with
   a short summary of the confirmed consequences.
3. Expandable “Review revision and counts” with full base and head SHAs and
   a table of Critical, Major, and Minor counts for each pass and unique totals.
   Keep the unique severity totals visible below the disclosure.
4. The severity and review-pass toolbar, followed by finding cards.
5. Needs investigation when present, then Review coverage with the scope of
   each pass and any Unchecked areas. Distinguish no findings from no review.

Render each confirmed finding once. Group cards by their primary pass in
Coding Standards, Security and Privacy, then Correctness and Reliability order;
put PR-structure findings in a final PR structure group. Within each group,
rank Critical, Major, then Minor. Omit groups with no cards. Wrap each group in
`<section class="section">` with a `section-heading` div and an `h2` title.
Record every contributing pass on the card, including findings in PR structure.

For each card, use a stable `finding_id`, a visible number such as `F01`, a
severity slug (`critical`, `major`, or `minor`), and space-separated pass slugs
(`coding-standards`, `security-privacy`, `correctness-reliability`). Render pass
names as `<span class="tag">` badges. Populate `location_html` with a paragraph
containing the file and line permalink at the pinned head, or the PR metadata
link when appropriate. Populate `fields_html` with `dt`/`dd` pairs for Evidence,
Consequence, Correction, and Standard when applicable. Keep the prose concise.

Needs investigation stays outside the confirmed finding counts and filters.
Use the card template with `class="investigation"` instead of
`class="finding {{severity_slug}}"`, show the investigation status, and state
the missing evidence. Copy controls still apply. Review coverage also remains
visible while findings are filtered.

### Filters

Start with every severity and pass selected. A card matches when its severity
is selected and at least one contributing pass is selected. “Critical + Major”
changes only severity; “Show all” resets both groups. Selecting no options in
either group shows no confirmed findings. Shared findings count once in the
visible total, regardless of how many selected passes match.

Keep the verdict and overall counts unchanged while filtering. Hide groups
with no visible cards and show “No findings match the selected filters” when
none match. Without JavaScript, show all content and hide interactive controls.
The manual quote fields remain available. Preserve the template's keyboard
support, light and dark themes, responsive layout, and full-report printing.

Before delivery, check combined severity and pass selections, a shared finding
matching either pass, a pass with no findings, an empty selection, and Show all
restoring every card. Check that the visible count and group visibility follow
the selected filters while review coverage stays visible.

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
