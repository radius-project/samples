# SQLPad UI + Radius.Data/sqlServerDatabases (Azure SQL)

This sample provisions an Azure SQL logical server and database through `Radius.Data/sqlServerDatabases` using an Azure Verified Module (AVM) recipe. It builds and runs SQLPad as a browser UI with a preconfigured connection to the provisioned database.

## What this sample shows
- **Resource type:** `Radius.Data/sqlServerDatabases`
- **Cloud backing (Azure):** Azure SQL via the AVM `mcr.microsoft.com/bicep/avm/res/sql/server:0.21.4` module (`env-azure.bicep`).
- **Application:** SQLPad `v7.5.7` from commit `ab1f0c03269f0178b9449d34505ce3462271f340`, built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** A developer-authored secure `password` parameter is set on the SQL Server resource and reused in the SQLPad `azure_sql` connection.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, SQL Server database resource, SQLPad image build, and SQLPad container. |
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
SQLPad was archived by its maintainers in August 2025; this sample pins tag `v7.5.7` and remains suitable as a sample. The container listens on port 3000, disables auth with the default admin role, and configures an `azure_sql` connection using driver `sqlserver`, encryption on, and certificate trust disabled.

The SQL recipe creates database `appdb` on a Basic Azure SQL database and allows Azure services through the server firewall. The SQLPad data path is `/var/lib/sqlpad` inside the container.
