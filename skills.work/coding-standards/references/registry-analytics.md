# Registry analytics

Read this alongside backend, frontend, security, and testing references when
their conditions match. Use the domain model in the current branch; historical
dashboard implementations are not specifications for the current analysis API.

## Definitions and data

- Validate analysis-kind, statistic, variable-type, and placement compatibility
  when saving a definition and when running it. A saved reference can become
  stale after registry design changes; validate its complete identity against
  the current registry design.
- When adding an analysis family, trace schema variants, transport mappers,
  candidates, save validation, execution, generated clients, UI controls,
  result labels, and agent tools. Exercise create and run through GraphQL for
  each supported input kind, including alternate numeric representations.
- Dataset rows preserve the domain's unit of observation. Declare how patients,
  event entries, and repeated form entries align, how values broadcast between
  levels, and how filters change the denominator. Test repeated and missing
  entries rather than assuming one row per patient.
- Distinguish date-only values from timestamps before day bucketing. Timestamps
  use the domain's timezone policy; date-only values do not imply a registry
  timezone. Preserve tuple components in compound identities, or use an
  encoding whose delimiter cannot collide with valid input values.
- Distinguish missing answers, empty datasets, suppressed results, invalid
  definitions, and real zero values. Labels, totals, percentages, and numeric
  summaries must describe the same population and input.
- Bound caller-controlled and stored numbers that allocate arrays, generate
  buckets, or drive loops. GraphQL integer validity alone does not bound work.
- Bound actual scans, cells, memory, and concurrent work where data size demands
  it. Limiting chart output does not limit input cost. Report resource exhaustion
  accurately rather than returning an ordinary empty result.
- Validate finite computed numbers before transport serialization. Cover empty,
  all-missing, and single-value inputs in calculation tests so invalid numbers
  do not emerge as a generic GraphQL serialization error.

## Privacy and errors

- Resolve patient/site scope from server authorization before loading answers.
  Registry or dashboard access alone does not grant access to all patient sites.
- Apply the configured minimum group size to the released aggregate and its
  relevant population. Check totals, complements, missing groups, and metadata
  for disclosures that bypass suppression. Test boundaries around the threshold.
- A minimum group size of zero is an explicit supported configuration where
  the domain allows it. Changing its floor or required permission is a product
  and privacy decision, not a value to invent while fixing another defect.
- Identify the required audit boundary for independently callable aggregate
  reads. Preserve the established audit contract; do not assume a dashboard
  view audits every separate API call or invent a per-card audit policy.
- Translated errors retain the actual failure reason. A missing statistic,
  incompatible variable, stale placement, and empty result need their own
  accurate handling rather than one misleading fallback message.
