# Issue tracker: GitLab

Issues and specs for this repo live as GitLab issues. Use `glab` for all operations and infer the project from `git remote -v`.

## Conventions

- **Create**: `glab issue create --title "..." --description "..."`
- **Read**: `glab issue view <number> --comments`
- **List**: `glab issue list -F json`
- **Comment**: `glab issue note <number> --message "..."`
- **Labels**: `glab issue update <number> --label "..."` or `--unlabel "..."`
- **Close**: comment first, then run `glab issue close <number>`

## Merge requests as a triage surface

**MRs as a request surface: no.** Set this to `yes` when external merge requests should enter the triage queue.

When enabled, use the corresponding `glab mr` commands.

## Publish and fetch

Publishing creates a GitLab issue. Fetching runs `glab issue view <number> --comments`.

## Wayfinding operations

- **Map**: one issue labelled `wayfinder:map`
- **Child ticket**: an issue whose description starts with `Part of #<map>` and whose label is `wayfinder:<type>`
- **Blocking**: GitLab's native blocking link; fall back to `Blocked by: #<number>` in the body when unavailable
- **Frontier**: open map children with no open blocker and no assignee, in map order
- **Claim**: `glab issue update <number> --assignee @me`
- **Resolve**: comment with the answer, close the ticket, then add a gist and link under the map's Decisions so far
