# Issue tracker: Local Markdown

Issues and specs for this repo live as ignored markdown files under `.scratch/`.

## Conventions

- One effort per directory: `.scratch/<effort>/`
- The spec is `.scratch/<effort>/spec.md`
- Implementation issues are one file per ticket at `.scratch/<effort>/issues/<NN>-<slug>.md`, numbered from `01`
- Triage state is a `Status:` line near the top of each issue file; `triage-labels.md` defines the values
- Comments and conversation history append under `## Comments`

## Publish and fetch

When a skill says to publish to the issue tracker, create a file under `.scratch/<effort>/`.

When a skill says to fetch a ticket, read the referenced file. The user will normally pass its path or number.

## Wayfinding operations

- **Map**: `.scratch/<effort>/map.md`, containing Destination, Notes, Decisions so far, Not yet specified, and Out of scope
- **Child ticket**: `.scratch/<effort>/issues/<NN>-<slug>.md`, with `Type: research|prototype|grilling|task` and `Status: open|claimed|resolved`
- **Blocking**: `Blocked by: NN, NN`; a ticket is unblocked when every listed file is resolved
- **Frontier**: open, unblocked, unclaimed tickets ordered by number
- **Claim**: set `Status: claimed` before starting work
- **Resolve**: append the result under `## Answer`, set `Status: resolved`, then add a gist and link under the map's Decisions so far
