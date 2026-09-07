# Domain Docs

How the engineering skills consume this repo's domain documentation.

## Before exploring, read these

- `CONTEXT.md` at the repo root, or
- `CONTEXT-MAP.md` at the repo root when it exists; read each linked `CONTEXT.md` relevant to the work
- ADRs under `docs/adr/` that affect the work; in a multi-context repo, also check context-specific ADR directories

Missing domain files require no warning. The `domain-modeling` skill creates them when terms or decisions are resolved.

## Layout

Use one `CONTEXT.md` and `docs/adr/` at the repo root for a single-context repo.

Use a root `CONTEXT-MAP.md` for a multi-context repo. The map names each context and points to its `CONTEXT.md`; system-wide ADRs stay under root `docs/adr/`, and context-specific ADRs stay with that context.

## Use the glossary

Use the term defined in `CONTEXT.md` whenever output names a domain concept. If a needed concept is absent, reconsider whether the project uses that concept or raise the gap for `domain-modeling`.

Surface output that conflicts with an ADR and name the ADR. Do not silently replace an existing decision.
