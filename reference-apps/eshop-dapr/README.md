# eShop on Dapr reference application

Visit the [Project Radius docs](https://radapp.dev/getting-started/reference-apps/eshop-dapr/) to learn more and try it out.

## Source

This reference app is a "radified" version of the [eShop on Dapr](https://github.com/dotnet-architecture/eShopOnDapr) .NET reference application.

Special thanks to [@amolenk](https://github.com/amolenk) for his implementation of eShop on Dapr (as well as the original implementation).

## Deploy

1. [Install the rad CLI](https://radapp.dev/getting-started/)
2. [Initialize a new Radius environment](https://radapp.dev/getting-started/)
3. Clone the repository and switch to the app directory:
   ```bash
   git clone https://github.com/project-radius/samples.git
   cd samples/reference-apps/eshop-dapr
   ```
4. Deploy the app:
   ```bash
   rad deploy main.bicep -p sqlAdministratorLoginPassword=<INSERT_8_OR_MORE_CHARACTER_PASSWORD_WITH_NUMBERS_LETTERS_AND_SPECIAL_CHARACTERS>
   ```

## Endpoints

- Main UI: `/`
- Health status: `/health`
- Logs: `/log/`
