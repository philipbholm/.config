# Root Cause Tracing

## Overview

Bugs often manifest deep in the call stack: `git init` in the wrong directory, a
file created in the wrong location, a database opened with the wrong path. The
instinct is to fix where the error appears, but that is the symptom.

**Core principle:** trace backward through the call chain until you find the
original trigger, then fix at the source.

**Use when:** the error happens deep in execution rather than at an entry point,
the stack trace shows a long call chain, it's unclear where the invalid data
originated, or you need to find which test triggers the problem.

If you trace back and hit a dead end — no caller you can inspect — fixing at the
symptom point is the remaining option. Add defense-in-depth validation either
way.

## The Tracing Process

### 1. Observe the symptom
```
Error: git init failed in ~/project/packages/core
```

### 2. Find the immediate cause

What code directly causes this?
```typescript
await execFileAsync('git', ['init'], { cwd: projectDir });
```

### 3. Ask what called this
```typescript
WorktreeManager.createSessionWorktree(projectDir, sessionId)
  → called by Session.initializeWorkspace()
  → called by Session.create()
  → called by test at Project.create()
```

### 4. Keep tracing up

What value was passed?
- `projectDir = ''` (empty string)
- Empty string as `cwd` resolves to `process.cwd()`
- That's the source code directory

### 5. Find the original trigger

Where did the empty string come from?
```typescript
const context = setupCoreTest(); // Returns { tempDir: '' }
Project.create('name', context.tempDir); // Accessed before beforeEach!
```

## Adding Stack Traces

When you can't trace manually, add instrumentation:

```typescript
// Before the problematic operation
async function gitInit(directory: string) {
  const stack = new Error().stack;
  console.error('DEBUG git init:', {
    directory,
    cwd: process.cwd(),
    nodeEnv: process.env.NODE_ENV,
    stack,
  });

  await execFileAsync('git', ['init'], { cwd: directory });
}
```

Use `console.error()` in tests — a logger may be suppressed.

**Run and capture:**
```bash
npm test 2>&1 | grep 'DEBUG git init'
```

**Analyze the traces:** look for test file names, find the line number
triggering the call, identify the pattern (same test? same parameter?).

## Finding Which Test Causes Pollution

If something appears during tests but you don't know which test, use the
bisection script in this directory:

```bash
./find-polluter.sh '.git' 'src/**/*.test.ts'
```

It runs tests one by one and stops at the first polluter. See the script for
usage.

## Worked Example: Empty projectDir

**Symptom:** `.git` created in `packages/core/` (source code)

**Trace chain:**
1. `git init` runs in `process.cwd()` ← empty `cwd` parameter
2. `WorktreeManager` called with empty `projectDir`
3. `Session.create()` passed empty string
4. Test accessed `context.tempDir` before `beforeEach`
5. `setupCoreTest()` returns `{ tempDir: '' }` initially

**Root cause:** top-level variable initialization accessing an empty value.

**Fix:** made `tempDir` a getter that throws if accessed before `beforeEach`.

**Plus defense-in-depth:**
- Layer 1: `Project.create()` validates the directory
- Layer 2: `WorkspaceManager` validates not empty
- Layer 3: `NODE_ENV` guard refuses `git init` outside tmpdir
- Layer 4: stack trace logging before `git init`

## Stack Trace Tips

- **In tests:** use `console.error()`, not a logger — the logger may be
  suppressed
- **Before the operation:** log before the dangerous call, not after it fails
- **Include context:** directory, cwd, environment variables, timestamps
- **Capture the stack:** `new Error().stack` shows the complete call chain
