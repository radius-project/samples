# Container Apps Store reference application

Visit the [Project Radius docs](https://radapp.dev/getting-started/reference-apps/container-app-store/) to learn more and try it out.

## Source

This reference app is a "radified" version of the [Container Apps Store](https://github.com/Azure-Samples/container-apps-store-api-microservice) reference application.

## Deploy

1. [Install the rad CLI](https://radapp.dev/getting-started/)
1. [Initialize a new Radius environment](https://radapp.dev/getting-started/)
1. Clone the repository and switch to the app directory:
   ```bash
   git clone https://github.com/radius-project/samples.git
   cd samples/reference-apps/container-app-store
   ```
1. Deploy the app:
    ```bash
    rad deploy iac/app.bicep
    ```
1. To swap from using redis as a container to Microsoft.Storage/storageAccounts, change the module in the app.bicep file from `infra-selfhosted.bicep` to `infra-azure.bicep`.