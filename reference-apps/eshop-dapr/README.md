# eShop on Dapr reference application

Visit the [Project Radius docs](https://radapp.dev/getting-started/reference-apps/eshop-dapr/) to learn more and try it out.

## Source

This reference app is a "radified" version of the [eShop on Dapr](https://github.com/dotnet-architecture/eShopOnDapr) .NET reference application.

Special thanks to [@amolenk](https://github.com/amolenk) for his implementation of eShop on Dapr (as well as the original implementation).

## Deploy

1. [Install the rad CLI](https://radapp.dev/getting-started/)
1. [Initialize a new Radius environment](https://radapp.dev/getting-started/)
1. Clone the repository and switch to the app directory:
   ```bash
   git clone https://github.com/project-radius/samples.git
   cd samples/reference-apps/eshop-dapr
   ```
1. Deploy the app:
   ```bash
   rad deploy main.bicep --parameters sqlAdministratorLoginPassword=Pass@word
   ```

## Endpoints

- Main UI: `/`
- Health status: `/health`
- Logs: `/log/`
