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

```markdown
## Summary
Brief description of what changed and why.

## Changes
- Bullet points of specific changes

## Testing
How to verify the changes work.
```

## Hooks

- **commit**: Pre-commit hook must pass
- **push**: Pre-push hook must pass

If hooks fail, fix the issues. Never skip with `--no-verify`.
