# Release artifacts and workflows

Start with these files under `.github/workflows/` in the Ledidi repository.
Fetch and inspect their current definitions and the version at the candidate
tag before dispatching; a workflow runs at its selected ref.

| Component | Build workflow | Deploy workflow | Production tag prefix |
|-----------|----------------|-----------------|-----------------------|
| registries-service | build-and-publish-registries.yml | deploy.yml | registries-service-prod |
| codelist | build-and-publish-codelist.yml | deploy.yml | codelist-service-prod |
| registries-frontend | build-and-publish-registries-frontend.yml | deploy-registries-frontend.yml | registries-frontend-prod |

Service production tags end in an ECS task-definition revision. The build
registers that revision; deploy.yml rolls the selected revision onto the service
and waits for stability. Resolve cluster and service names from the deployment
environment instead of assuming a fixed account or target.

Frontend production tags end in a numeric timestamp. The build stages the
production bundle by commit SHA. The deployment copies the staged assets to the
production bucket and invalidates CloudFront. Inspect the frontend workflow's
`await-backend-schema` job and its script: frontend deployment can depend on a
compatible backend. Do not assume the components can always deploy independently.

Query tags with `git ls-remote --tags origin 'refs/tags/<prefix>.*'` after
confirming origin identifies the correct repository. Match the full tag prefix
and numeric suffix, sort numerically, and retain both tag and peeled commit
records. Lexical order puts revision 99 after 100.

Deployment history must be filtered by the exact component and production
environment as well as the workflow. deploy.yml also handles other services
and test tags. A missing match in a short page of runs is not proof that the
component has never deployed. Read further pages or report the lookup limit.
