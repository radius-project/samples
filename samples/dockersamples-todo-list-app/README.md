# Docker todo-list-app + Radius.Data/mySqlDatabases (Azure MySQL)

This sample provisions an Azure Database for MySQL flexible server and database through `Radius.Data/mySqlDatabases` using an Azure Verified Module (AVM) recipe. It builds and runs Docker's getting-started todo-list-app against that MySQL database.

## What this sample shows
- **Resource type:** `Radius.Data/mySqlDatabases`
- **Cloud backing (Azure):** Azure Database for MySQL via the AVM `mcr.microsoft.com/bicep/avm/res/db-for-my-sql/flexible-server:0.10.3` module (`env-azure.bicep`).
- **Application:** Docker getting-started todo-list-app `v1.0.0` from commit `55680777bc46c59d3fe0ab9ff7e79ee947d0c757`, built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** A developer-authored secure `password` parameter is set on the MySQL resource and reused by the app as `MYSQL_PASSWORD`.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, MySQL database resource, todo app image build, and todo app container. |
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
The MySQL recipe creates database `appdb`, admin user `radadmin`, and a firewall rule for the supplied client egress IP. The sample disables MySQL `require_secure_transport` so the todo app can connect with its standard MySQL settings.

The todo app listens on port 3000 and receives `MYSQL_HOST`, `MYSQL_DB`, `MYSQL_USER`, and `MYSQL_PASSWORD` from `app.bicep`. The Radius database resource uses MySQL version `8.0`.
