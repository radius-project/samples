# Radius samples demo app + Radius.Data/redisCaches (Azure Managed Redis)

This sample provisions an Azure Managed Redis (Redis Enterprise) cache through `Radius.Data/redisCaches` using an Azure Verified Module (AVM) recipe. It builds and runs the Radius samples demo app against the provisioned Redis cache.

## What this sample shows
- **Resource type:** `Radius.Data/redisCaches`
- **Cloud backing (Azure):** Azure Managed Redis via the AVM `mcr.microsoft.com/bicep/avm/res/cache/redis-enterprise:0.5.1` module (`env-azure.bicep`).
- **Application:** Radius samples demo app `demo-e2e` from commit `190d9c4c84278980d9fae402330bd5ead76b31a5`, built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** The recipe exposes the Redis connection string under nested `outputs.secrets.url`. Radius materializes it in a managed secret, and the app explicitly binds that key to `CONNECTION_REDIS_URL` with a `secretKeyRef` backed by `redis.properties.secrets`.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, Redis cache resource, demo app image build, and demo app container. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container image from source with a `Radius.Compute/containerImages` recipe and pushes it to a registry you supply. When deploying `env-azure.bicep`, provide:
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built image. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repository must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

## Notes
The Redis recipe maps size `S` to the `Balanced_B0` Azure Managed Redis SKU and enables access-key authentication on the default database. The demo container listens on port 3000.

The environment recipe maps the Redis host and port to ordinary Radius properties and materializes the primary connection string only in the managed secret. The app explicitly binds the secret key; it does not rely on plain connection auto-injection for the credential.

Additional deployment details:
- The app declares a `connections.redis` relationship to the cache.
- The image build uses the Radius samples demo source pinned by commit.
