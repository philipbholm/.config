---
name: systematic-debugging
description: Use when investigating a bug, test failure, or unexpected behavior whose cause is not yet identified — traces to the root cause before changing code.
---

# Systematic Debugging

Find the root cause before fixing. A fix aimed at the symptom leaves the cause
in place, and the bug comes back somewhere else.

The process below is fast for simple bugs and is the only thing that works for
hard ones. It matters most exactly when it feels most skippable: under time
pressure, when the fix looks obvious, and after a previous fix didn't hold.

## Phase 1 — Root cause investigation

**Read the error message.** All of it, including the stack trace. Note line
numbers, file paths, error codes. Errors frequently contain the answer.

**Reproduce it.** Can you trigger it reliably? What are the exact steps? Does it
happen every time? If it isn't reproducible, gather more data rather than
guessing.

**Check recent changes.** `git diff`, recent commits, new dependencies, config
changes, environmental differences.

**Instrument component boundaries.** When the system has several components —
CI → build → signing, API → service → database — add diagnostics before
proposing a fix. For each boundary: log what enters, log what exits, verify
config and environment propagation, check state at each layer. Run once to
gather evidence about *where* it breaks, then investigate that component.

```bash
# Layer 1: Workflow
echo "=== Secrets available in workflow: ==="
echo "IDENTITY: ${IDENTITY:+SET}${IDENTITY:-UNSET}"

# Layer 2: Build script
echo "=== Env vars in build script: ==="
env | grep IDENTITY || echo "IDENTITY not in environment"

# Layer 3: Signing script
echo "=== Keychain state: ==="
security list-keychains
security find-identity -v

# Layer 4: Actual signing
codesign --sign "$IDENTITY" --verbose=4 "$APP"
```

This tells you which layer fails: secrets → workflow ✓, workflow → build ✗.

**Trace the data flow.** Where does the bad value originate? What called this
with the bad value? Keep tracing up until you find the source, and fix there.
For the full backward-tracing technique, see
[root-cause-tracing.md](root-cause-tracing.md).

## Phase 2 — Pattern analysis

Find similar code in the same codebase that works. If you're implementing a
known pattern, read the reference implementation completely rather than
skimming. List every difference between the working and broken versions,
however small — "that can't matter" is where the bug usually is. Check what
else the component needs: settings, config, environment, assumptions.

## Phase 3 — Hypothesis and testing

State one hypothesis clearly and specifically: "I think X is the root cause
because Y." Test it with the smallest possible change, one variable at a time.

If it worked, move to Phase 4. If it didn't, form a *new* hypothesis rather than
stacking another fix on top. If you don't understand something, say so and
investigate instead of guessing.

## Phase 4 — Implementation

**Write a failing test first.** Simplest possible reproduction — an automated
test, or a one-off script if there's no framework. See the
`test-driven-development` skill.

**Make one fix**, addressing the root cause. No "while I'm here" improvements,
no bundled refactoring.

**Confirm the test passes, nothing else broke, and the original issue is
actually gone.**

**If the fix didn't work,** return to Phase 1 with what you learned. After three
failed fixes, stop fixing and question the architecture instead.

## When three fixes have failed

The pattern to recognise: each fix reveals new shared state or coupling
somewhere else, each fix creates new symptoms elsewhere, and fixes start
requiring massive refactoring to implement.

That is not a failed hypothesis — it's a wrong architecture. Stop and ask
whether the pattern is fundamentally sound, or whether it's being kept through
inertia. Discuss it before attempting a fourth fix.

## When there is no root cause

Some issues really are environmental, timing-dependent, or external. When the
investigation genuinely lands there: document what you investigated, implement
appropriate handling (retry, timeout, clear error message), and add
monitoring or logging for next time.

Most "no root cause" conclusions are incomplete investigations, so be honest
about which one this is.

## Supporting techniques

- [root-cause-tracing.md](root-cause-tracing.md) — trace bugs backward through
  the call stack to the original trigger
- [defense-in-depth.md](defense-in-depth.md) — validate at multiple layers once
  the root cause is known
- [condition-based-waiting.md](condition-based-waiting.md) — replace arbitrary
  timeouts with condition polling
- [find-polluter.sh](find-polluter.sh) — bisect a test suite to find which test
  pollutes shared state; run from the project root by path
  (`bash ~/.claude/skills/systematic-debugging/find-polluter.sh`)
