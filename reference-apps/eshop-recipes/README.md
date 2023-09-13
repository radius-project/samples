# eShop on Recipes reference application

## Source

This reference app is a "radified" version of the [eShop on containers](https://github.com/dotnet-architecture/eShopOnContainers) .NET reference application.

## Deploy

1. Have a kubernetes cluster handy from the [supported clusters](https://docs.radapp.dev/operations/platforms/kubernetes/supported-clusters/).
   - (AWS only) Make sure that each of the Subnets in your EKS cluster Subnet Group are within the list of [supported MemoryDB availability zones](https://docs.aws.amazon.com/memorydb/latest/devguide/subnetgroups.html) 
1. [Install the rad CLI](https://radapp.dev/getting-started/)
1. [Initialize a new Radius environment](https://radapp.dev/getting-started/)
1. Clone the repository and switch to the app directory:
   ```bash
   git clone https://github.com/project-radius/samples.git
   cd samples/reference-apps/eshop
   ```
1. Deploy the environment (choose which type of hosting infrastructure you wish to use):
   ```bash
   # AWS
   rad deploy iac/environments/aws.bicep

   # Azure
   rad deploy iac/environments/azure.bicep

   # Containers
   rad deploy iac/environments/containers.bicep
   ```
1. Deploy the application:
    ```bash
    rad deploy iac/eshop.bicep
    ```
