# Bento pipeline + Radius.Messaging/rabbitMQ (Azure Service Bus)

This sample provisions an Azure Service Bus namespace and queue through `Radius.Messaging/rabbitMQ` using an Azure Verified Module (AVM) recipe. It builds and runs Bento as a producer/consumer streaming pipeline over the provisioned queue.

## What this sample shows
- **Resource type:** `Radius.Messaging/rabbitMQ`
- **Cloud backing (Azure):** Azure Service Bus via the AVM `mcr.microsoft.com/bicep/avm/res/service-bus/namespace:0.16.2` module (`env-azure.bicep`).
- **Application:** WarpStream Bento `v1.18.1`, built from source via `Radius.Compute/containerImages` with `resources/docker/Dockerfile` and run via `imageReference`.
- **Credential model:** The recipe exposes the queue connection string under nested `outputs.secrets.connectionString`. Both containers read the non-secret `queue.properties.host` directly and consume the connection string via a `secretKeyRef` backed by the recipe-managed secret, deriving the Service Bus AMQP endpoint and SAS key from it. The application also supplies the password-secret resource ID required by the built-in RabbitMQ schema; the Azure Service Bus recipe does not consume that placeholder credential.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, Bento image build, queue resource, and producer/consumer containers. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container image from source with a `Radius.Compute/containerImages` recipe and pushes it to a registry you supply. When deploying `env-azure.bicep`, provide:
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built image. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repository must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

## Notes
The `producer` container generates messages every five seconds and publishes them to the `jobs` queue over AMQP 1.0. The `consumer` container continuously reads the same queue with lock renewal enabled and logs messages to stdout.

Both containers run the same built Bento image and generate their pipeline YAML files at startup. The Service Bus recipe creates the `jobs` queue from the Radius resource's `queue` property.

Additional deployment details:
- The app declares a `connections.rabbitmq` relationship to the queue.
- The Service Bus namespace uses the Standard SKU with local auth enabled.
