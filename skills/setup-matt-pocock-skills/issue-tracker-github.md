# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues. Use `gh` for all operations and infer the repository from `git remote -v`.

## Conventions

- **Create**: `gh issue create --title "..." --body "..."`
- **Read**: `gh issue view <number> --comments`
- **List**: `gh issue list --state open --json number,title,body,labels,comments`
- **Comment**: `gh issue comment <number> --body "..."`
- **Labels**: `gh issue edit <number> --add-label "..."` or `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

## Pull requests as a triage surface

**PRs as a request surface: no.** Set this to `yes` when external PRs should enter the triage queue.

When enabled, use the corresponding `gh pr` commands. GitHub shares issue and PR numbers, so resolve a bare number by trying `gh pr view` before `gh issue view`.

## Publish and fetch

Publishing creates a GitHub issue. Fetching runs `gh issue view <number> --comments`.

## Wayfinding operations

- **Map**: one issue labelled `wayfinder:map`
- **Child ticket**: a GitHub sub-issue, or a task-list child when sub-issues are unavailable; label it `wayfinder:<type>`
- **Blocking**: GitHub's native issue dependency; fall back to `Blocked by: #<number>` in the body when dependencies are unavailable
- **Frontier**: open map children with no open blocker and no assignee, in map order
- **Claim**: `gh issue edit <number> --add-assignee @me`
- **Resolve**: comment with the answer, close the ticket, then add a gist and link under the map's Decisions so far
