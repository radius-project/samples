# mongo-express + Radius.Data/mongoDatabases (Azure Cosmos DB for MongoDB)

This sample provisions a MongoDB-compatible Azure Cosmos DB account and database through `Radius.Data/mongoDatabases` using an Azure Verified Module (AVM) recipe. It builds and runs mongo-express as a browser UI for the provisioned database.

## What this sample shows
- **Resource type:** `Radius.Data/mongoDatabases`
- **Cloud backing (Azure):** Azure Cosmos DB for MongoDB via the AVM `mcr.microsoft.com/bicep/avm/res/document-db/database-account:0.19.0` module (`env-azure.bicep`).
- **Application:** mongo-express `v1.0.2`, built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** The recipe exposes the database connection string under nested `outputs.secrets.connectionString`. The app consumes it as `ME_CONFIG_MONGODB_URL` via a `secretKeyRef` backed by `mongo.properties.secrets` and declares a `connections.mongo` relationship.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, Mongo database resource, mongo-express image build, and mongo-express container. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container image from source with a `Radius.Compute/containerImages` recipe and pushes it to a registry you supply. When deploying `env-azure.bicep`, provide:
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built image. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repository must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

## Notes
The app disables mongo-express basic auth for the sample and connects with SSL enabled. The environment can optionally allow a supplied client egress IP through the Cosmos DB firewall; otherwise public access remains disabled.

The Radius resource creates database `mongo_db` in the Cosmos DB account. The account name is supplied as an `app.bicep` parameter so verification can use the same globally unique value in Radius and Azure.

Additional deployment details:
- The mongo-express container exposes web port 8081.
- The image build uses the upstream mongo-express repository at tag `v1.0.2`.
