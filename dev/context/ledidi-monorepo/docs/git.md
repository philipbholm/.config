# Git Conventions

## Commits

### Message Format

```
<type>: <description>

[optional body]
```

### Types

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes nor adds |
| `test` | Adding or updating tests |
| `docs` | Documentation |
| `chore` | Maintenance (deps, config) |

### Rules

- Imperative mood: "Add feature" not "Added feature"
- Lowercase after type
- No period at end
- Body explains _why_, not _what_

### Examples

```
feat: add patient export to CSV

fix: prevent duplicate form submissions

refactor: extract validation into shared utility

test: add integration tests for medication list
```

## Pull Requests

### Defaults

- Create as **draft**
- Apply the `risk:standard` label. Any other label needs my go-ahead first.
- Always include a PR description (see format below)
- After creating one, open its URL in the browser

Any PR touching product code under `services/registries/src/` or
`apps/registries-frontend/src/` trips the story-map reminder — tests, stories
and generated files don't count. Update the data files under
`services/registries/docs/story-map/src/data/` when the change adds, removes, or
changes a user-visible story; otherwise tick the **Story map reviewed** checkbox
the bot appends to the description. Until one of the two happens, that check
stays red and the bot keeps commenting.

Then run `gh pr checks <n>` and report what it says. `pr-checks` is the only
required check on master — Chromatic, the Playwright suites, and the story-map
reminder are informational, so a red one there is worth reporting rather than
blocking on.

### Size

| Metric | Ceiling | Target |
|--------|---------|--------|
| Files changed | 40 | < 25 |
| Lines changed | 3000 | < 1500 |

Going over is an exception that needs a reason, not a routine outcome. When a
task looks like it will exceed these, the first move is to find a split, not to
ask for a pass.

### Scope

A PR does one thing. Once it does two, it gets appreciably harder to review.

- Extract large renames, formatting sweeps, and lint-rule changes into their own
  PRs so they don't bury the real diff
- Stacking PRs onto one deliverable is fine when revertability matters or when
  shipping only part of the change makes no sense
- Continuously merging to master is equally fine — ship unfinished work behind a
  feature flag

### Title Format

```
<gitmoji> <description>
```

**Always start with a gitmoji.**

### Common Gitmojis

| Emoji | Code | When |
|-------|------|------|
| ✨ | `:sparkles:` | New feature |
| 🐛 | `:bug:` | Bug fix |
| ♻️ | `:recycle:` | Refactor |
| 🧪 | `:test_tube:` | Tests |
| 📝 | `:memo:` | Documentation |
| 🔧 | `:wrench:` | Configuration |
| ⬆️ | `:arrow_up:` | Upgrade dependency |
| 🗑️ | `:wastebasket:` | Remove code/files |
| 🎨 | `:art:` | Improve structure/format |
| ⚡ | `:zap:` | Performance |
| 🔒 | `:lock:` | Security |

### Title Examples

```
✨ Add patient export functionality
🐛 Fix duplicate form submissions
♻️ Extract validation into shared utility
🧪 Add medication list integration tests
```

### Description

Two required sections:

```markdown
## Why
The motivation — problem being solved, context, or reason for the change.

## What
What the PR does — the concrete changes made.
```

## Review Comments

Resolve only threads started by an AI reviewer. Threads started by a person stay
open for that person to close, however thoroughly you've addressed them.

## Hooks

- **commit**: Pre-commit hook must pass
- **push**: Pre-push hook must pass

If hooks fail, fix the issues. Never skip with `--no-verify`.

Committing and pushing don't need my approval.
