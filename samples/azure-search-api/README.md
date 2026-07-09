# Go search API service + Radius.AI/search (Azure AI Search)

This sample provisions an Azure AI Search service through `Radius.AI/search` using an Azure Verified Module (AVM) recipe. It builds and runs a small Go HTTP API that stores documents in the search index and queries them through the Azure AI Search REST API.

## What this sample shows
- **Resource type:** `Radius.AI/search`
- **Cloud backing (Azure):** Azure AI Search via the AVM `mcr.microsoft.com/bicep/avm/res/search/search-service:0.12.2` module (`env-azure.bicep`).
- **Application:** Go search API service `v1`, built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** The recipe exposes the admin key under nested `outputs.secrets.apiKey`. The app declares `connections.search` (Radius auto-injects the non-secret `CONNECTION_SEARCH_ENDPOINT`) and consumes the key explicitly as `CONNECTION_SEARCH_APIKEY` via a `secretKeyRef` backed by `searchService.properties.secrets`, which the Go service reads.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, search resource, search API image build, and search API container. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |
| `src/` | Go source for the search API service (stdlib only), its tests, and Dockerfile. |

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container image from source with a `Radius.Compute/containerImages` recipe and pushes it to a registry you supply. When deploying `env-azure.bicep`, provide:
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built image. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repository must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

## Notes
The containerImages recipe builds from `git::https://github.com/radius-project/samples.git//samples/azure-search-api/src?ref=edge`; this source lands in this repo on merge. The service uses only the Go standard library, calls Azure AI Search REST API version `2024-07-01`, ensures an index on startup, and exposes `GET /healthz`, `POST /documents`, and `GET /search?q=...` on port 8080.

The default index name is `radius-sample`, overridable with `SEARCH_INDEX_NAME`. `POST /documents` accepts JSON documents with `id` and `content`, and `/search` returns the upstream Azure AI Search JSON response.

Additional deployment details:
- The Azure AI Search service uses the Basic SKU with one replica and one partition.
- The container image builds with the Dockerfile under `src/`.
