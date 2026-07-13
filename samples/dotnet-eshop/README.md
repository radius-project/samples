# .NET eShop + Radius.Data/postgreSqlDatabases (Azure PostgreSQL)

This sample provisions Azure Database for PostgreSQL flexible servers through `Radius.Data/postgreSqlDatabases` using an Azure Verified Module (AVM) recipe, then builds and runs the [.NET eShop](https://github.com/dotnet/eShop) reference application against them.

## What this sample shows
- **Resource type:** `Radius.Data/postgreSqlDatabases` (used four times — one per eShop database).
- **Cloud backing (Azure):** Azure Database for PostgreSQL via the AVM `mcr.microsoft.com/bicep/avm/res/db-for-postgre-sql/flexible-server:0.15.2` module (`env-azure.bicep`).
- **Application:** .NET eShop, pinned to upstream commit [`9b4f943`](https://github.com/dotnet/eShop/commit/9b4f9434f46fdc5c1a6e9e936af2868340cdbc48) (MIT), built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** Developer-authored secure `databasePassword` and `eventBusPassword` parameters are composed into complete connection strings inside app-owned `Radius.Security/secrets` resources; containers read those connection strings via `secretKeyRef` rather than inline-interpolated passwords.

## Architecture
eShop is a .NET Aspire microservices application. This sample runs its nine deployable services plus Redis and RabbitMQ as `Radius.Compute/containers`:

- **Data-backed services:** `catalog-api` (catalogdb), `identity-api` (identitydb), `ordering-api` + `order-processor` (orderingdb), `webhooks-api` (webhooksdb).
- **Stateless services:** `basket-api` (Redis + event bus), `payment-processor` (event bus), `webhooksclient`, `webapp`.
- **Infrastructure containers:** `redis` (`redis:8-alpine`) and `eventbus` (`rabbitmq:4-management-alpine`), run from pinned published images (not built from source).

Each API applies its own EF Core migrations at startup — eShop registers a `MigrationHostedService` (see `src/Shared/MigrateDbContextExtensions.cs`) that runs `Database.MigrateAsync` before the app serves traffic — so no separate schema loader or `initSql` is required. `Radius.Compute/routes` resources front `identity-api`, `webapp`, and `webhooksclient` at `/`.

### Omitted service: mobile-bff
The upstream PR topology included a `mobile-bff` service, but the pinned eShop source ships **no `mobile-bff` project** (there is no `src/Mobile.Bff*/*.csproj`). Because there is nothing to build from source, `mobile-bff` (its container and route) is intentionally omitted from this sample.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, four PostgreSQL database resources, app secrets, per-service image builds, containers, and routes. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |
| `src/Dockerfile` | Generic multi-stage .NET build that clones the pinned upstream commit and publishes a single project selected by the `PROJECT` build arg. |

## Source and image build
Upstream eShop is an Aspire solution and ships **no per-service Dockerfiles**, so this sample owns one generic `src/Dockerfile`. It clones `dotnet/eShop` at commit `9b4f9434f46fdc5c1a6e9e936af2868340cdbc48` and, driven by build args, restores and publishes exactly one project:
- `PROJECT` — the csproj to publish, e.g. `src/Catalog.API/Catalog.API.csproj`.
- `ESHOP_COMMIT` — the pinned upstream commit (defaulted to the SHA above).
- `ENTRY_DLL` — the published entry assembly, e.g. `Catalog.API.dll` (a project named `X` publishes `X.dll`).

eShop targets `net10.0`, so the build stage uses `mcr.microsoft.com/dotnet/sdk:10.0` and the runtime stage `mcr.microsoft.com/dotnet/aspnet:10.0`. The published output is architecture-neutral, so the build stage is pinned to `$BUILDPLATFORM` and the runtime stage resolves the target architecture — the default multi-architecture build needs no emulation. The runtime stage runs as a non-root user.

`app.bicep` builds one `Radius.Compute/containerImages` resource per service (`identity-api`, `basket-api`, `catalog-api`, `ordering-api`, `order-processor`, `payment-processor`, `webhooks-api`, `webhooksclient`, `webapp`) and exposes two build parameters:
- `source` — the build context, defaulting to this sample's `src` directory published on the `samples` repo `edge` branch. Override it to build from a fork/branch.
- `buildPlatform` — set to a single platform (e.g. `linux/amd64`) to build single-arch images faster; empty builds the default `linux/amd64` + `linux/arm64` images.

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container images from source with `Radius.Compute/containerImages` recipes and pushes them to a registry you supply. When deploying `env-azure.bicep`, provide:
- `serverName` — the base name for the PostgreSQL flexible servers. Each database gets its own server named `<serverName>-<database>` (e.g. `<serverName>-catalogdb`), so keep `serverName` to roughly 40 lowercase alphanumerics/hyphens or fewer to stay within the 63-character server-name limit.
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built images. Create it before deploying.

> **Cost note:** this sample provisions **four** Azure PostgreSQL flexible servers (one each for `catalogdb`, `identitydb`, `orderingdb`, and `webhooksdb`). Each runs on the burstable `Standard_B1ms` SKU. Delete them promptly after use (see Cleanup).

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repositories must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

When deploying `app.bicep`, provide:
- `databasePassword` — the PostgreSQL admin password shared by the four databases (secure).
- `eventBusPassword` — the RabbitMQ password for the event bus (secure).
- `identityUrl`, `webAppUrl`, `webhooksClientUrl` — externally reachable URLs. These are **required and deterministic**: set each to the public hostname of the corresponding route (`identity-api`, `webapp`, `webhooksclient`). eShop's OIDC flows redirect the browser to `identityUrl` and use `webAppUrl`/`webhooksClientUrl` as OAuth callbacks, so they must be the hostnames a browser (and the services) can actually reach, not in-cluster service names.
- `imageTag` (optional) — defaults to the pinned commit SHA.

## pgvector
eShop's Catalog service stores product embeddings in a `vector(384)` column and its EF Core migration enables the PostgreSQL `vector` extension (`Npgsql:PostgresExtension:vector`). On Azure Database for PostgreSQL flexible server, `CREATE EXTENSION vector` only succeeds if the extension is allowlisted on the server. `env-azure.bicep` therefore sets the AVM `configurations` parameter to add `azure.extensions = VECTOR` (allowlisted for every server the recipe creates). eShop's Catalog EF migration then creates the extension itself at startup — no manual `CREATE EXTENSION` step is needed.

## Smoke test
`catalog-api` reads seeded product data from Azure PostgreSQL after its EF Core migration and seeder run. To exercise the Azure PostgreSQL data path, port-forward the container and query the catalog:

```sh
kubectl port-forward deployment/catalog-api 8080:8080
# read seeded catalog items back from Azure PostgreSQL
curl -s "http://localhost:8080/api/catalog/items?pageSize=5&pageIndex=0"
```

A response listing seeded catalog items confirms the application migrated the schema and read product data back from the provisioned Azure PostgreSQL database.

## Notes
Every connection string uses the literal port `5432` and requires TLS (`SSL Mode=Require;Trust Server Certificate=true`); the Azure recipe maps only the server FQDN (`host`) into the resource, so the port is not read from `properties.port`. The database firewall must allow the client egress IP (`clientIpAddress`). Each PostgreSQL resource requests size `S`, which the recipe maps to the burstable `Standard_B1ms` SKU. The event bus URL is a complete `amqp://` string (with the real password) delivered via an app-owned secret and injected with `secretKeyRef`.

## Cleanup
Delete the Radius application and environment to remove the in-cluster resources, then delete the four Azure PostgreSQL flexible servers (or the whole resource group) to stop incurring cost.
