# Review quality

## Findings

Raise findings for concrete defects, documented-standard violations, or
improvements whose benefit is worth the author's time. Explain the correctness
or maintenance cost of a design finding; a named code smell or personal taste
is not evidence. Repository conventions take precedence over generic advice.

Inspect the surrounding code, callers, tests, schemas, and configuration needed
to establish the consequence. A diff hunk alone is not enough. Skip findings
already enforced by the repository's lint, type, formatting, or build checks.

Each finding states the file and line, evidence, consequence, relevant rule or
spec requirement when applicable, and a suggested correction. Keep findings
concise without omitting confirmed problems to meet a word or count limit.
Separate plausible but unconfirmed risks under **Needs investigation**, stating
the missing evidence. Distinguish unexamined areas from areas with no findings.

When a review uses severity, apply these definitions:

- **Critical** — a credible security, privacy, destructive-data, or severe
  availability risk that can cause substantial harm.
- **Major** — a confirmed problem the author should fix before merge.
- **Minor** — a worthwhile improvement that does not need to block the merge.

## Isolated passes

Give each reviewer the pinned diff, assigned pass, standards or spec sources,
and this reference. Supply topic-specific reference paths rather than loading
every topic into the coordinator. Each reviewer reads the sources relevant to
its pass and follows affected consumers when deciding which rules apply.

The coordinator reads the diff to identify scope, then verifies candidate
findings against the code and relevant sources. Reviewers inspect surrounding
code during their passes; the coordinator need not repeat that entire survey
before dispatch. Treat reviewer output as candidates, not finished findings.
Remove unsupported findings and duplicates within each pass. The calling
workflow decides how to present findings shared by multiple passes.
