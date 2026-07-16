# LiteLLM proxy + Radius.AI/models (Azure OpenAI)

This sample provisions an Azure OpenAI account and chat deployment through `Radius.AI/models` using an Azure Verified Module (AVM) recipe. It builds and runs LiteLLM as a proxy that exposes the model through a local OpenAI-compatible endpoint.

## What this sample shows
- **Resource type:** `Radius.AI/models`
- **Cloud backing (Azure):** Azure OpenAI via the AVM `mcr.microsoft.com/bicep/avm/res/cognitive-services/account:0.15.0` module (`env-azure.bicep`).
- **Application:** LiteLLM `v1.91.0`, built from source via `Radius.Compute/containerImages` and run via `imageReference`.
- **Credential model:** The recipe exposes the API key under nested `outputs.secrets.apiKey`. The app reads the non-secret `model.properties.endpoint` directly and consumes the key as `AZURE_API_KEY` via a `secretKeyRef` backed by `model.properties.secrets`.

## Files
| File | Role |
| --- | --- |
| `app.bicep` | Developer view: the Radius application, model resource, LiteLLM image build, and LiteLLM container. |
| `env-azure.bicep` | Platform-engineer view: the `recipePacks` binding the type to the AVM module plus supporting recipes, and the `environment`. |
| `bicepconfig.json` | Radius Bicep extension configuration. |

## Deploying
Deploy `env-azure.bicep` (the environment) first, then `app.bicep`.

This sample builds its container image from source with a `Radius.Compute/containerImages` recipe and pushes it to a registry you supply. When deploying `env-azure.bicep`, provide:
- `containerImagesRegistry` — an OCI registry you can push to (e.g. `ghcr.io/your-org`).
- `containerImagesRegistrySecretName` — the name of a Kubernetes Secret (`username`/`password`) in the environment namespace, used to authenticate the BuildKit **push** of the built image. Create it before deploying.

Image **pull** auth is separate: the `containerImages` recipe does not configure kubelet pull credentials, so the built image repository must be publicly readable by the cluster, or you must configure a Kubernetes image-pull secret (e.g. a `kubernetes.io/dockerconfigjson` `imagePullSecret` on the namespace's `default` ServiceAccount) before deploying `app.bicep` — otherwise the app pods fail with `ImagePullBackOff`.

## Notes
The LiteLLM container writes a minimal config at startup, maps the Azure OpenAI deployment to model name `chat`, and listens on port 4000. It uses Azure OpenAI API version `2025-04-01-preview` and sets a sample `LITELLM_MASTER_KEY`.

The model resource requests `gpt-5-mini`; the environment recipe creates the matching Azure OpenAI deployment named `chat`. Override the Azure account name with the environment parameter required by your deployment flow.

Additional deployment details:
- The container exposes the LiteLLM proxy on port 4000.
- The image build uses the upstream LiteLLM repository at tag `v1.91.0`.
