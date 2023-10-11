# eShop on Radius reference application

Visit the [Project Radius docs](https://radapp.dev/getting-started/reference-apps/eshop/) to learn more and try it out.

## Source

This reference app is a "radified" version of the [eShop on containers](https://github.com/dotnet-architecture/eShopOnContainers) .NET reference application.

## Deploy

1. Have a kubernetes cluster handy from the [supported clusters](https://docs.radapp.dev/operations/platforms/kubernetes/supported-clusters/).
   - (AWS only) Make sure that each of the Subnets in your EKS cluster Subnet Group are within the list of [supported MemoryDB availability zones](https://docs.aws.amazon.com/memorydb/latest/devguide/subnetgroups.html) 
1. [Install the rad CLI](https://radapp.dev/getting-started/)
1. [Initialize a new Radius Environment](https://radapp.dev/getting-started/)
1. Clone the repository and switch to the app directory:
   ```bash
   git clone https://github.com/project-radius/samples.git
   cd samples/reference-apps/eshop
   ```
1. Deploy the app (choose which type of hosting infrastructure you wish to use):

   ### Containerized infrastructure
   
    ```bash
    rad deploy iac/eshop.bicep
    ```

   ### Azure infrastructure
   
    ```bash
    rad deploy iac/eshop.bicep -p platform=azure
    ```

   ### AWS infrastructure
   
    ```bash
    rad deploy iac/eshop.bicep -p platform=aws -p eksClusterName=<YOUR_EKS_CLUSTER_NAME>
    ```
    
