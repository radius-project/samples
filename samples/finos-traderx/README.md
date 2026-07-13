# FINOS TraderX + Radius.Data/postgreSqlDatabases (Azure PostgreSQL)

This sample provisions an Azure Database for PostgreSQL flexible server and database through `Radius.Data/postgreSqlDatabases` using an Azure Verified Module (AVM) recipe, then builds and runs the [FINOS TraderX](https://github.com/finos/traderX) reference trading application against it.

## What this sample shows
- **Resource type:** `Radius.Data/postgreSqlDatabases`
- **Cloud backing (Azure):** Azure Database for PostgreSQL via the AVM `mcr.microsoft.com/bicep/avm/res/db-for-postgre-sql/flexible-server:0.15.2` module (`env-azure.bicep`). TraderX uses a single database.
- **Application:** FINOS TraderX, pinned to upstream commit [`afe174d`](https://github.com/finos/traderX/commit/afe174d8feaf0a059b68423f3ff2db570eb6d843) on the `code/generated-state-009-order-management-matcher` branch (Apache-2.0). Nine microservices are built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** A developer-authored secure `password` parameter is set on the PostgreSQL resource and mirrored into an app-owned `Radius.Security/secrets` resource; every service reads the database password via `secretKeyRef` rather than an inline connection string.

## Architecture
TraderX is a multi-service trading sample. This sample runs:

| Component | Image source | Port |
| --- | --- | --- |
| `reference-data` | source build (`reference-data/Dockerfile.compose`) | 18085 |
| `people-service` | source build (`people-service/Dockerfile.compose`) | 18089 |
| `account-service` | source build (`account-service/Dockerfile.compose`) | 18088 |
| `position-service` | source build (`position-service/Dockerfile.compose`) | 18090 |
| `trade-processor` | source build (`trade-processor/Dockerfile.compose`) | 18091 |
| `trade-service` | source build (`trade-service/Dockerfile.compose`) | 18092 |
| `price-publisher` | source build (`price-publisher/Dockerfile.compose`) | 18100 |
| `order-matcher` | source build (`order-matcher/Dockerfile.compose`) | 18110 |
| `web-front-end-angular` | source build (`web-front-end/angular/Dockerfile.compose`) | 18093 |
| `nats-broker` | published image `nats:2.14-alpine` (inline config) | 4222 / 8222 / 8081 |
| `edge-proxy` | published image `nginx:1.27-alpine` (inline config) | 8080 |
| `schema-loader` | sample-owned build (`src/schema-loader/Dockerfile`) | — |

`account-service`, `position-service`, `trade-processor`, and `order-matcher` connect to the provisioned Azure PostgreSQL database. `edge-proxy` is an nginx reverse proxy that fronts every service (and the Angular UI) on a single port; a `Radius.Compute/routes` resource fronts the edge proxy at `/`. Services publish and subscribe to trade/price events through the NATS broker.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, PostgreSQL database resource, app secret, the 9 source-built service images + containers, the NATS broker, the nginx edge proxy, the schema loader, and the route. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |
| `src/schema-loader/Dockerfile` | Schema loader image (`FROM postgres:16-alpine`) bundling the schema SQL and entrypoint. |
| `src/schema-loader/entrypoint.sh` | Waits for Azure PostgreSQL, applies the schema/seed idempotently, prints `SCHEMA_LOAD_COMPLETE`, then stays alive. |
| `src/schema-loader/schema.sql` | TraderX schema + seed data (accounts, users, trades, positions, order book). |

## Source and image build
The nine TraderX microservices each ship a `Dockerfile.compose` in the upstream repository, so the images are built directly from source subdirectories of `finos/traderX` at commit `afe174d8feaf0a059b68423f3ff2db570eb6d843`. Each `Radius.Compute/containerImages` resource sets `build.source` to `git::https://github.com/finos/traderX.git//<service-dir>?ref=<sha>` with `dockerfile: 'Dockerfile.compose'`. The Angular front end lives under `web-front-end/angular`.

`nats-broker` and `edge-proxy` are not built — they use the pinned published images `nats:2.14-alpine` and `nginx:1.27-alpine` with configuration supplied inline via `command`/`args`.

`app.bicep` exposes these build parameters:
- `sourceRepo` — base go-getter source for the upstream repository (default `git::https://github.com/finos/traderX.git`). Override to build from a fork.
- `imageTag` — the tag applied to the built images; defaults to the pinned commit and is also used as the `ref` for the source builds.
- `schemaLoaderSource` — the build context for the sample-owned schema loader, defaulting to this sample's `src/schema-loader` directory published on the `samples` repo `edge` branch.
- `buildPlatform` — set to a single platform (e.g. `linux/amd64`) to build single-arch images faster; empty builds the default `linux/amd64` + `linux/arm64` images. Upstream `Dockerfile.compose` files do not declare `$BUILDPLATFORM`, so CI overrides `buildPlatform=linux/amd64` for these images.

## Schema loading
Azure ignores the `Radius.Data/postgreSqlDatabases` `initSql`, so the TraderX schema and seed data are applied explicitly by a dedicated `schema-loader` container. It builds from `src/schema-loader` (`FROM postgres:16-alpine`), waits for the Azure PostgreSQL server with `pg_isready`, then runs `psql -f schema.sql`. The SQL is idempotent (it begins with `DROP TABLE IF EXISTS ...`), so re-running is safe. On success the container prints `SCHEMA_LOAD_COMPLETE` and then `sleep infinity` to remain a healthy long-running resource.

The schema loader connects to Azure PostgreSQL using `PGHOST` (the literal server FQDN from `database.properties.host`), `PGPORT=5432`, `PGDATABASE`/`PGUSER`, the password via `secretKeyRef`, and `PGSSLMODE=require`.

**Startup ordering:** the DB-backed services (`account-service`, `position-service`, `trade-processor`, `order-matcher`) start in parallel with the schema loader. Their Hibernate/JPA layers may fail while the tables do not yet exist; because the schema loader applies the schema within seconds and Kubernetes restarts crashed pods, the services recover automatically once the schema is present. No upstream source is modified to coordinate this ordering.

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container images from source with a `Radius.Compute/containerImages` recipe and pushes them to a registry you supply. When deploying `env-azure.bicep`, provide:
- `serverName` — a globally-unique PostgreSQL flexible server name.
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built images. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repositories must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

When deploying `app.bicep`, provide:
- `password` — the database admin password.
- `publicUrl` — the externally reachable edge URL (the host clients use to reach the edge route). This is a required, deterministic parameter: it is injected as `CORS_ALLOWED_ORIGINS` into every service, so it must match the URL the browser and API clients actually use, otherwise cross-origin requests are rejected.

## Smoke test
The `order-matcher` service exposes a REST order API (see `order-matcher/openapi.yaml` and `OrderController.java` in the pinned source). Through the edge proxy the paths are prefixed with `/order-matcher/`:
- `POST /order-matcher/orders` — create an order (returns `201 Created` with the created order, including its generated `orderId`).
- `GET /order-matcher/orders/{orderId}` — fetch a single order.
- `GET /order-matcher/orders?status=open&accountId=<id>` — list orders.

To exercise the Azure PostgreSQL write/read path end-to-end, POST a unique order through the edge, capture the returned `orderId`, then GET it back:

```sh
EDGE=<publicUrl>   # e.g. http://<edge-host>

# create an order (writes to Azure PostgreSQL via order-matcher)
ORDER_ID=$(curl -s -X POST "$EDGE/order-matcher/orders" \
  -H "Content-Type: application/json" \
  -d '{"accountId":22214,"security":"AAPL","side":"Buy","quantity":10,"limitPrice":190.50}' \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["orderId"])')
echo "created order: $ORDER_ID"

# read it back
curl -s "$EDGE/order-matcher/orders/$ORDER_ID"
```

A successful round-trip (the GET returns the same `orderId` you created) confirms the application wrote to and read from the provisioned Azure PostgreSQL database.

## Notes
- Every database connection uses the literal port `5432`; the Azure recipe maps only the server FQDN (`host`) into the resource, so the port is never read from `properties.port`.
- Azure PostgreSQL requires TLS. The four Spring Boot services set `SPRING_DATASOURCE_URL` to `jdbc:postgresql://<host>:5432/traderx?sslmode=require` (Spring relaxed binding overrides the upstream `spring.datasource.url`), and the schema loader sets `PGSSLMODE=require`. No upstream source is modified.
- The nginx edge proxy uses `server_name _;` so it accepts requests for any host (the reachable edge/route host), and `publicUrl` must be set to that reachable edge URL for CORS to succeed.
- The PostgreSQL resource requests size `S`, which the recipe maps to the burstable `Standard_B1ms` SKU. The database firewall must allow the client egress IP (`clientIpAddress`).

## Cleanup
Delete the Radius application and environment to remove the in-cluster resources, then delete the Azure PostgreSQL flexible server (or the whole resource group) to stop incurring cost.
