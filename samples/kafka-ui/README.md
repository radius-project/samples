# Kafbat Kafka UI + Radius.Messaging/kafka (Azure Event Hubs)

This sample provisions a Kafka-compatible Azure Event Hubs namespace and event hub through `Radius.Messaging/kafka` using an Azure Verified Module (AVM) recipe. It runs Kafbat Kafka UI against that broker so you can inspect the provisioned topic from a web UI.

## What this sample shows
- **Resource type:** `Radius.Messaging/kafka`
- **Cloud backing (Azure):** Azure Event Hubs via the AVM `mcr.microsoft.com/bicep/avm/res/event-hub/namespace:0.14.2` module (`env-azure.bicep`).
- **Application:** Kafbat Kafka UI `ghcr.io/kafbat/kafka-ui:v1.5.0`, run from a pinned published image.
- **Credential model:** The recipe exposes the broker connection string under nested `outputs.secrets.connectionString`. The app consumes it as `RAD_SECRET_CONNECTIONSTRING` via a `secretKeyRef` backed by `kafkaBroker.properties.secrets`; the Kafka JAAS config then references it with Kubernetes `$(RAD_SECRET_CONNECTIONSTRING)` substitution.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, Kafka resource, and Kafka UI container. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

## Notes
Kafka UI connects to Event Hubs over Kafka protocol on port 9093 with `SASL_SSL` and `PLAIN` authentication.

This is the only sample in this set that does not build its app image from source. It uses the official published image because building a Kafka UI from source is impractical for a small sample: Kafbat, AKHQ, and Kafdrop Dockerfiles require prebuilt JARs, and Redpanda Console has no production Dockerfile.

The Event Hubs recipe creates the `events` event hub from the Radius resource's `topic` property. The environment also includes the standard containers and secrets recipes used by the app container.

Additional deployment details:
- The Kafka UI container exposes web port 8080.
- The broker host is combined with `.servicebus.windows.net:9093`.
