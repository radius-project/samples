# pgweb + Radius.Data/postgreSqlDatabases (Azure PostgreSQL)

This sample provisions an Azure Database for PostgreSQL flexible server and database through `Radius.Data/postgreSqlDatabases` using an Azure Verified Module (AVM) recipe. It builds and runs pgweb as a browser UI for the provisioned PostgreSQL database.

## What this sample shows
- **Resource type:** `Radius.Data/postgreSqlDatabases`
- **Cloud backing (Azure):** Azure Database for PostgreSQL via the AVM `mcr.microsoft.com/bicep/avm/res/db-for-postgre-sql/flexible-server:0.15.2` module (`env-azure.bicep`).
- **Application:** pgweb `v0.17.0`, built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** A developer-authored secure `password` parameter is set on the PostgreSQL resource and reused in `PGWEB_DATABASE_URL`.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, PostgreSQL database resource, pgweb image build, and pgweb container. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container image from source with a `Radius.Compute/containerImages` recipe and pushes it to a registry you supply. When deploying `env-azure.bicep`, provide:
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built image. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repository must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

Provide the database admin `password` parameter when deploying `app.bicep`.

## Notes
The pgweb container listens on port 8081 and connects with `sslmode=require` as user `radadmin` to database `appdb`. Its image build sets `BUILDKIT_CONTEXT_KEEP_GIT_DIR=1` because the pgweb Dockerfile needs the `.git` directory. The database firewall must allow the client egress IP.

The PostgreSQL resource requests size `S`, which the recipe maps to the burstable `Standard_B1ms` SKU. If no client IP is provided, the recipe omits the PostgreSQL firewall rule.
