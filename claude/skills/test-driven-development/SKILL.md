---
name: test-driven-development
description: Use when writing a test for new behavior or a bug fix — covers the red-green-refactor cycle and what makes a test honest.
---

# Test-Driven Development

Write the test first. Watch it fail. Write the minimal code that makes it pass.

The failure is the point. A test you never watched fail has not proved it can
catch anything — it may be asserting on the wrong thing, on the implementation
rather than the behavior, or on nothing at all. Watching it go red, for the
reason you expected, is the only evidence that it works.

Prototypes you intend to throw away, generated code, and config files are
reasonable exceptions.

## Red — write the failing test

One minimal test showing what should happen. One behavior, a name that
describes that behavior, real code rather than mocks.

<Good>
```typescript
test('retries failed operations 3 times', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('fail');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```
Clear name, tests real behavior, one thing
</Good>

<Bad>
```typescript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```
Vague name, tests the mock rather than the code
</Bad>

## Verify red — watch it fail

```bash
npm test path/to/test.test.ts
```

Confirm the test *fails* rather than errors, that the failure message is the
one you expected, and that it fails because the feature is missing — not
because of a typo or a bad import.

If it passes, you are testing behavior that already exists; fix the test. If it
errors, fix the error and re-run until it fails cleanly.

## Green — minimal code

Simplest thing that passes the test. No extra features, no refactoring of
neighboring code, no improvements beyond what the test demands.

<Good>
```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```
Just enough to pass
</Good>

<Bad>
```typescript
async function retryOperation<T>(
  fn: () => Promise<T>,
  options?: {
    maxRetries?: number;
    backoff?: 'linear' | 'exponential';
    onRetry?: (attempt: number) => void;
  }
): Promise<T> {
  // YAGNI
}
```
Over-engineered
</Bad>

Run the suite. The new test passes, the existing ones still pass, and the
output is clean. If the new test fails, fix the code rather than the test.

## Refactor

Once green: remove duplication, improve names, extract helpers. Tests stay
green; behavior does not change.

Then write the next failing test.

## Good tests

| Quality | Good | Bad |
|---------|------|-----|
| **Minimal** | One thing. "and" in the name? Split it. | `test('validates email and domain and whitespace')` |
| **Clear** | Name describes the behavior | `test('test1')` |
| **Shows intent** | Demonstrates the desired API | Obscures what the code should do |

When writing or changing any test, read [writing-good-tests.md](writing-good-tests.md)
for the rules that keep tests honest:

- Name the production change that would make the test fail — before writing it
- Assert on real behavior, never on mock behavior
- Keep test-only code in test utilities, out of production classes
- Understand a dependency's side effects before mocking it

## Worked example: a bug fix

**Bug:** empty email accepted.

**Red**
```typescript
test('rejects empty email', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email required');
});
```

**Verify red**
```bash
$ npm test
FAIL: expected 'Email required', got undefined
```

**Green**
```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) {
    return { error: 'Email required' };
  }
  // ...
}
```

**Verify green**
```bash
$ npm test
PASS
```

**Refactor** — extract validation if more fields need it.

A bug fix always starts with a test that reproduces the bug. That test proves
the fix and prevents the regression.

## When stuck

| Problem | Solution |
|---------|----------|
| Don't know how to test | Write the wished-for API. Write the assertion first. Ask. |
| Test too complicated | The design is too complicated. Simplify the interface. |
| Must mock everything | The code is too coupled. Use dependency injection. |
| Test setup huge | Extract helpers. Still complex? Simplify the design. |
