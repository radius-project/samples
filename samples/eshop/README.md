# eShop on Radius

A fork of the upstream [.NET eShop reference application](https://github.com/dotnet/eShop),
modeled on Radius. The app source is unchanged from upstream — we only added what Radius
needs to deploy it:

- **`src/*/Dockerfile` (9)** — upstream ships none (it uses .NET Aspire / SDK publish); the
  Radius in-cluster builder needs one per service.
- **`.radius/`** — the Radius model (`app.bicep`), environment + recipe pack (`env.bicep`),
  and `bicepconfig.json`.

It doubles as a **reference input for the app-modeling skill**: a realistic multi-service
app (containers + Redis + PostgreSQL + RabbitMQ) to generate and validate a Radius
`app.bicep` from real-world source.

## What gets deployed

`.radius/app.bicep` defines a single `Radius.Core/applications` (`eshop`) with:

| Kind | Resources |
| --- | --- |
| `Radius.Compute/containerImages` | 9 images built from source (`identity-api`, `basket-api`, `catalog-api`, `ordering-api`, `order-processor`, `payment-processor`, `webhooks-api`, `webhooksclient`, `webapp`) |
| `Radius.Compute/containers` | The 9 eShop services wired together over cluster DNS |
| `Radius.Data/redisCaches` | Basket cache |
| `Radius.Data/postgreSqlDatabases` | Catalog, Identity, Ordering, Webhooks databases |
| `Radius.Messaging/rabbitMQ` | Event bus |

The graph renders in the Radius canvas / `rad app graph .radius/app.bicep`.

## Prerequisites

- An **edge / preview `rad` CLI and control plane**.
- An AKS cluster with the Radius control plane installed, and an Azure subscription +
  resource group for the backing services (Redis Enterprise, PostgreSQL Flexible
  Server, Service Bus).
- An OCI registry the in-cluster builder can push to (e.g. `ghcr.io/<org>`), and a
  Kubernetes secret with push/pull credentials for it (used to push the built images and
  pull them back to run the containers). Omit the secret for a public registry.

## Deploy

1. **Create the environment + recipe pack** ([`.radius/env.bicep`](./.radius/env.bicep)):

   ```bash
   rad deploy .radius/env.bicep \
     --parameters environmentName=eshop \
     --parameters environmentNamespace=eshop \
     --parameters azureSubscriptionId=<your-subscription-id> \
     --parameters azureResourceGroup=<your-resource-group> \
     --parameters containerImagesRegistry=ghcr.io/<your-org> \
     --parameters containerImagesRegistrySecretName=<your-registry-pull-secret>
   ```

2. **Deploy the application**:

   ```bash
   rad deploy .radius/app.bicep --environment eshop
   ```

   The `containerImages` resources clone this folder
   (`git::https://github.com/radius-project/samples.git//samples/eshop?ref=<branch>`)
   and build each service image with BuildKit inside the cluster before the
   `containers` start. Update the `?ref=` in `.radius/app.bicep` if you deploy from a
   fork or a different branch.

## Layout

```
samples/eshop/
├── .radius/app.bicep   # Radius application model (the sample's entry point)
├── .radius/env.bicep   # Environment + recipe pack (Azure/AKS)
├── src/                # eShop application source + per-service Dockerfiles
└── README.md
```
