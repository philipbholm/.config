# Condition-Based Waiting

## Overview

Flaky tests often guess at timing with arbitrary delays. That creates race
conditions: the test passes on a fast machine and fails under load or in CI.

**Core principle:** wait for the actual condition you care about, not a guess
about how long it takes.

**Use when:** tests have arbitrary delays (`setTimeout`, `sleep`,
`time.sleep()`), tests are flaky, tests time out when run in parallel, or you're
waiting for an async operation to complete.

**Exception:** when the test is about timing behavior itself — debounce,
throttle intervals — an explicit delay is the point. Document why.

## Core Pattern

```typescript
// ❌ BEFORE: Guessing at timing
await new Promise(r => setTimeout(r, 50));
const result = getResult();
expect(result).toBeDefined();

// ✅ AFTER: Waiting for condition
await waitFor(() => getResult() !== undefined);
const result = getResult();
expect(result).toBeDefined();
```

## Quick Patterns

| Scenario | Pattern |
|----------|---------|
| Wait for event | `waitFor(() => events.find(e => e.type === 'DONE'))` |
| Wait for state | `waitFor(() => machine.state === 'ready')` |
| Wait for count | `waitFor(() => items.length >= 5)` |
| Wait for file | `waitFor(() => fs.existsSync(path))` |
| Complex condition | `waitFor(() => obj.ready && obj.value > 10)` |

## Implementation

Generic polling function:
```typescript
async function waitFor<T>(
  condition: () => T | undefined | null | false,
  description = 'condition',
  timeoutMs = 5000
): Promise<T> {
  const startTime = Date.now();

  while (true) {
    const result = condition();
    if (result) return result;

    if (Date.now() - startTime > timeoutMs) {
      throw new Error(`Timeout waiting for ${description} after ${timeoutMs}ms`);
    }

    await new Promise(r => setTimeout(r, 10)); // Poll every 10ms
  }
}
```

See [condition-based-waiting-example.ts](condition-based-waiting-example.ts) for
a complete implementation with domain-specific helpers (`waitForEvent`,
`waitForEventCount`, `waitForEventMatch`).

## Common Mistakes

**Polling too fast:** `setTimeout(check, 1)` wastes CPU — poll every 10ms.

**No timeout:** the loop runs forever if the condition is never met. Always
include a timeout with a clear error.

**Stale data:** caching state before the loop. Call the getter inside the loop
so each poll sees fresh data.

## When an Arbitrary Timeout Is Correct

```typescript
// Tool ticks every 100ms - need 2 ticks to verify partial output
await waitForEvent(manager, 'TOOL_STARTED'); // First: wait for condition
await new Promise(r => setTimeout(r, 200));   // Then: wait for timed behavior
// 200ms = 2 ticks at 100ms intervals - documented and justified
```

Three requirements: wait for the triggering condition first, base the delay on
known timing rather than a guess, and comment why.
