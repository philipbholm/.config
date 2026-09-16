# Registries examples

Resolve these paths from the current Ledidi checkout. Inspect the example and
nearby callers before applying its pattern; the named behavior is the example,
not every choice in the file. Prefer a closer current example when one exists.
If a path has moved, find its replacement before making a recommendation.

| Behavior | Example to inspect |
|----------|--------------------|
| Shared input labels, generated IDs, and error display | `apps/registries-frontend/src/components/Input/Input.tsx` |
| Translated form-schema factory and inferred form values | `apps/registries-frontend/src/app/[lang]/registries/[registryId]/collaborators/CollaboratorForm.tsx` |
| Named GraphQL input and result mapping | `services/registries/src/handlers/graphql/mappers/analysis/frequency.ts` |
| Event-driven projection updates using the registry transaction client | `services/registries/src/application/registry/sites/site-projection.ts` |
| Frontend GraphQL response setup through `registriesMocks().with*().apply()` | `apps/registries-frontend/test-util/registries-mocks.ts` and the nearest test using the relevant method |
| Analysis definition, computation, result, and calculation-test organization | `services/registries/src/application/analysis/frequency/` |

For a new analysis kind, compare the definition, computation, result, mapper,
chart, and tests with the closest existing kind. Explain differences required
by the analysis rather than copying its entire structure.
