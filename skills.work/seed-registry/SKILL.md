---
name: seed-registry
description: Seed a Ledidi demo registry in the current development stack. Use when the user says “seed with” a registry name or clinical area.
---

# Seed a Ledidi registry

Load the `dev-stack` skill and ensure the full stack is running. The seeder uses
GraphQL and PostgreSQL, so PostgreSQL alone is insufficient.

Run the seeder from `~/work/scripts`:

```bash
cd ~/work/scripts
npx tsx create-registry.ts <registry> --slot <n>
```

Use 20 patients unless the user names another count. Twenty is the script
default, so add `--patients <count>` only for another count. Add `--language`
only when the user names a language; otherwise each registry uses its own
default language: English for `nrras`, `mrgfus`, and `njr`, and Norwegian
Bokmål for the rest.

Compute the required slot from the registries GraphQL port rendered in the
checkout instructions: `(port - 4006) / 100`. The main checkout is slot 0.

| User phrase | Registry key |
|-------------|--------------|
| ankle fracture, ankelbrudd | `ankle` |
| headache, hodepine | `headache` |
| NOBAREV, paediatric rheumatology | `nobarev` |
| Parkinson | `parkinson` |
| cholesteatoma, kolesteatom | `kolesteatom` |
| myeloma, myelomatose | `myeloma` |
| robotic-assisted surgery, NRRAS | `nrras` |
| MRgFUS, focused ultrasound | `mrgfus` |
| joint replacement, NJR | `njr` |

Ask which registry the user means when the phrase matches none of the rows.
`npx tsx create-registry.ts <registry> --help` lists optional flags such as
`--completeness` and `--hip-only`.

The seeder deletes and rebuilds an existing registry with the same name. Run it
only against the local development stack, never a test or production endpoint.
