# SFTPGo + Radius.Storage/objectStorage (Azure Blob Storage)

This sample provisions an Azure Storage account and blob container through `Radius.Storage/objectStorage` using an Azure Verified Module (AVM) recipe. It builds and runs SFTPGo with an SFTP user backed by the provisioned Blob Storage container.

## What this sample shows
- **Resource type:** `Radius.Storage/objectStorage`
- **Cloud backing (Azure):** Azure Blob Storage via the AVM `mcr.microsoft.com/bicep/avm/res/storage/storage-account:0.32.1` module (`env-azure.bicep`).
- **Application:** SFTPGo `v2.7.4`, built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** The recipe exposes the storage account key under nested `outputs.secrets.accountKey`. The app reads the non-secret `store.properties.accountName` and `store.properties.containerName` directly and consumes the key as `AZ_KEY` via a `secretKeyRef` backed by `store.properties.secrets`, to initialize the SFTPGo Azure Blob filesystem.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, object storage resource, SFTPGo image build, and SFTPGo container. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container image from source with a `Radius.Compute/containerImages` recipe and pushes it to a registry you supply. When deploying `env-azure.bicep`, provide:
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built image. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repository must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

## Notes
SFTPGo uses an in-memory data provider and loads a generated `init.json` at startup. The sample exposes SFTP on port 2022 and the HTTP UI on port 8080, creates an admin user, and creates a `radius` user whose home directory maps to the Azure Blob container.

The object storage recipe creates a `Standard_LRS` StorageV2 account and a blob container named `data`. Blob public access is disabled, while network ACLs allow access for this sample.

Additional deployment details:
- The app declares a `connections.store` relationship to the object storage resource.
- The image build uses the upstream SFTPGo repository at tag `v2.7.4`.
