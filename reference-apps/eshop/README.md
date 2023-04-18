# eShop on Radius reference application

Visit the [Project Radius docs](https://radapp.dev/getting-started/reference-apps/eshop/) to learn more and try it out.

## Source

This reference app is a "radified" version of the [eShop on containers](https://github.com/dotnet-architecture/eShopOnContainers) .NET reference application.

## Deploy

> Note: If running on a local Kubernetes cluster, make sure to allocate at least 8GB of memory to your cluster. The default configuration is 4GB, which will cause the app to crash if run with other pods.

1. [Install the rad CLI](https://radapp.dev/getting-started/)
1. [Initialize a new Radius environment](https://radapp.dev/getting-started/)
1. Clone the repository and switch to the app directory:
   ```bash
   git clone https://github.com/project-radius/samples.git
   cd samples/reference-apps/eshop
   ```
1. Deploy the app (choose which type of hosting infrastructure you wish to use):

   ### Containerized infrastructure
    ```bash
    rad deploy iac/app.bicep -p adminPassword=<INSERT_8_OR_MORE_CHARACTER_PASSWORD_WITH_NUMBERS_LETTERS_AND_SPECIAL_CHARACTERS>
    ```

   ### Azure infrastructure
    ```bash
    rad deploy iac/app.azure.bicep
    ```

   ### AWS infrastructure
    ```bash
    rad deploy iac/app.aws.bicep -p adminPassword=<INSERT_8_OR_MORE_CHARACTER_PASSWORD_WITH_NUMBERS_LETTERS_AND_SPECIAL_CHARACTERS> -p eksClusterName=<YOUR_EKS_CLUSTER_NAME>
    ```
