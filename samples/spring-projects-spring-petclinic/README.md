# Spring PetClinic + Radius.Data/postgreSqlDatabases (Azure PostgreSQL)

This sample provisions an Azure Database for PostgreSQL flexible server and database through `Radius.Data/postgreSqlDatabases` using an Azure Verified Module (AVM) recipe, then builds and runs the [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) reference application against it.

## What this sample shows
- **Resource type:** `Radius.Data/postgreSqlDatabases`
- **Cloud backing (Azure):** Azure Database for PostgreSQL via the AVM `mcr.microsoft.com/bicep/avm/res/db-for-postgre-sql/flexible-server:0.15.2` module (`env-azure.bicep`).
- **Application:** Spring PetClinic, pinned to upstream commit [`51045d1`](https://github.com/spring-projects/spring-petclinic/commit/51045d1648dad955df586150c1a1a6e22ef400c2) (Apache-2.0), built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** A developer-authored secure `password` parameter is set on the PostgreSQL resource and mirrored into an app-owned `Radius.Security/secrets` resource; the container reads `POSTGRES_PASSWORD` via `secretKeyRef` rather than an inline connection string.

## Architecture
PetClinic runs its `postgres` Spring profile and connects to the provisioned Azure PostgreSQL database. It creates and seeds its own schema on startup (`spring.sql.init.mode=always`), so no separate schema loader is required. The container exposes port 8080 and a `Radius.Compute/routes` resource fronts it at `/`.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, PostgreSQL database resource, app secret, PetClinic image build, container, and route. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |
| `src/Dockerfile` | Multi-stage build that clones the pinned upstream commit, builds the jar with the Maven wrapper, and runs it on a pinned JRE. |

## Source and image build
Upstream Spring PetClinic ships no Dockerfile, so this sample owns `src/Dockerfile`. It clones `spring-projects/spring-petclinic` at commit `51045d1648dad955df586150c1a1a6e22ef400c2`, builds with `./mvnw -DskipTests clean package`, and runs the resulting jar on `eclipse-temurin:17-jre-jammy`. The jar is architecture-neutral, so the build stage is pinned to `$BUILDPLATFORM` and the runtime stage resolves the target architecture — the default multi-architecture build needs no emulation.

`app.bicep` exposes two build parameters:
- `source` — the build context, defaulting to this sample's `src` directory published on the `samples` repo `edge` branch. Override it to build from a fork/branch.
- `buildPlatform` — set to a single platform (e.g. `linux/amd64`) to build a single-arch image faster; empty builds the default `linux/amd64` + `linux/arm64` image.

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container image from source with a `Radius.Compute/containerImages` recipe and pushes it to a registry you supply. When deploying `env-azure.bicep`, provide:
- `serverName` — a globally-unique PostgreSQL flexible server name.
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built image. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repository must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

Provide the database admin `password` parameter when deploying `app.bicep`.

## Smoke test
PetClinic reports readiness at `/readyz` and liveness at `/livez` on port 8080. To exercise the Azure PostgreSQL data path, port-forward the container (or use the route host) and:

```sh
# create a new owner (writes to Azure PostgreSQL)
curl -s -X POST http://<host>/owners/new \
  -d "firstName=Ada&lastName=Lovelace&address=1+Analytical+Way&city=London&telephone=5551234567"
# read it back
curl -s "http://<host>/owners?lastName=Lovelace"
```

A successful round-trip confirms the application wrote to and read from the provisioned Azure PostgreSQL database.

## Notes
The connection URL uses the literal port `5432` and `sslmode=require`; the Azure recipe maps only the server FQDN (`host`) into the resource, so the port is not read from `properties.port`. The database firewall must allow the client egress IP (`clientIpAddress`). The PostgreSQL resource requests size `S`, which the recipe maps to the burstable `Standard_B1ms` SKU.

## Cleanup
Delete the Radius application and environment to remove the in-cluster resources, then delete the Azure PostgreSQL flexible server (or the whole resource group) to stop incurring cost.
