# Agent tools

- Prompts, examples, descriptions, schemas, and executable tool behavior describe
  the same contract. Update each supported locale and output variant when the
  contract changes; test examples against the actual schema or tool.
- A preview advertised as preventing invalid saves gates the mutation. Report
  actual terminal reasons, including when no computation occurred, instead of
  fabricating a privacy or analysis result for a failed attempt.
- Preserve concrete inferred tool result types. Use shared domain schemas
  where those schemas own the shape, rather than rebuilding untyped records
  and casting their fields in tests or consumers.
- Validate and authorize tool calls in application code. Check every required
  read and write permission for a composed tool flow; a prompt or tool list
  does not enforce authorization.
- Enforce retry limits, step limits, timeouts, and input/resource bounds in code.
  Instructions asking a model to stop do not bound execution. Recoverable tool
  errors explain what input can be corrected; unexpected failures reach the
  normal reporting boundary without exposing sensitive values.
- Persist assistant text even when a turn contains no tool call. Preserve
  tool-call/result pairing and the required conversation context across turns.
- Verify whether SDK callbacks deliver deltas or cumulative snapshots before
  accumulating history. Assert exact persisted message counts and order so a
  superficially complete transcript cannot hide duplication.
- Keep user-controlled labels distinct from tool-authored instructions and
  fields. When sanitizing display metadata for model input, test relevant
  Unicode controls and interactions between sanitization steps; do not apply
  that text transformation to stored clinical answers without a domain rule.
- Use the adapter's supported model capabilities. Share capability detection
  when multiple active adapters need the same rule; verify against the installed
  SDK and the actual configured model rather than guessing from its name.
