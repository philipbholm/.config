# Defense-in-Depth Validation

## Overview

When a bug came from invalid data, validating at the one place you found it
feels sufficient. But that single check can be bypassed by a different code
path, dropped in a refactor, or mocked out in a test.

**Core principle:** once the root cause is fixed, add validation at the layers
that would have caught the bad value, so the same class of bug can't return
unnoticed.

**Use when:** the root cause is identified and fixed, the bad value crossed
several layers before doing damage, more than one code path reaches the same
operation, or the failure was destructive — wrote outside its directory, deleted
data, corrupted shared state.

**Exception:** a bug contained in one function, reached by one caller, needs one
check. Extra layers there are code to maintain against a risk that doesn't
exist.

## Choosing Layers

The four layers below are a menu, not a checklist. Scale how many you add to the
blast radius of the bug: a wrong log line earns one entry check, `git init` in
the source tree earns all four.

- Entry validation catches most bad input, at the boundary where the error
  message still points somewhere useful
- Business logic validation catches values that are well-formed but wrong for
  this particular operation
- Environment guards prevent context-specific damage — the case for destructive
  operations
- Debug instrumentation buys forensics for whatever the other layers miss

### Layer 1: Entry Point Validation
**Purpose:** Reject obviously invalid input at API boundary

```typescript
function createProject(name: string, workingDirectory: string) {
  if (!workingDirectory || workingDirectory.trim() === '') {
    throw new Error('workingDirectory cannot be empty');
  }
  if (!existsSync(workingDirectory)) {
    throw new Error(`workingDirectory does not exist: ${workingDirectory}`);
  }
  if (!statSync(workingDirectory).isDirectory()) {
    throw new Error(`workingDirectory is not a directory: ${workingDirectory}`);
  }
  // ... proceed
}
```

### Layer 2: Business Logic Validation
**Purpose:** Ensure data makes sense for this operation

```typescript
function initializeWorkspace(projectDir: string, sessionId: string) {
  if (!projectDir) {
    throw new Error('projectDir required for workspace initialization');
  }
  // ... proceed
}
```

### Layer 3: Environment Guards
**Purpose:** Prevent dangerous operations in specific contexts

```typescript
async function gitInit(directory: string) {
  // In tests, refuse git init outside temp directories
  if (process.env.NODE_ENV === 'test') {
    const normalized = normalize(resolve(directory));
    const tmpDir = normalize(resolve(tmpdir()));

    if (!normalized.startsWith(tmpDir)) {
      throw new Error(
        `Refusing git init outside temp dir during tests: ${directory}`
      );
    }
  }
  // ... proceed
}
```

### Layer 4: Debug Instrumentation
**Purpose:** Capture context for forensics

```typescript
async function gitInit(directory: string) {
  const stack = new Error().stack;
  logger.debug('About to git init', {
    directory,
    cwd: process.cwd(),
    stack,
  });
  // ... proceed
}
```

## Applying the Pattern

When you find a bug:

1. **Trace the data flow** - Where does bad value originate? Where used?
2. **Map all checkpoints** - List every point data passes through
3. **Pick the layers that fit** - How much damage could the bad value do?
4. **Test each layer** - Try to bypass layer 1, verify layer 2 catches it

## Example from Session

Bug: Empty `projectDir` caused `git init` in source code

**Data flow:**
1. Test setup → empty string
2. `Project.create(name, '')`
3. `WorkspaceManager.createWorkspace('')`
4. `git init` runs in `process.cwd()`

**Four layers added:**
- Layer 1: `Project.create()` validates not empty/exists/writable
- Layer 2: `WorkspaceManager` validates projectDir not empty
- Layer 3: `WorktreeManager` refuses git init outside tmpdir in tests
- Layer 4: Stack trace logging before git init

## Key Insight

That bug earned all four, and each layer caught cases the others missed:
- Different code paths bypassed entry validation
- Mocks bypassed business logic checks
- Edge cases on different platforms needed environment guards
- Debug logging identified structural misuse

A bug that writes to one file through one caller would not have earned any of
them past layer 1.
