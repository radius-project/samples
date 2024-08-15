# eShop on Radius reference application

## Source

This reference app is a "radified" version of the [eShop on containers](https://github.com/dotnet-architecture/eShopOnContainers) .NET reference application.

## Deploy

1. Have a kubernetes cluster handy from the [supported clusters](https://docs.radapp.io/guides/operations/kubernetes/overview/#supported-kubernetes-clusters).
   - (AWS only) Make sure that each of the Subnets in your EKS cluster Subnet Group are within the list of [supported MemoryDB availability zones](https://docs.aws.amazon.com/memorydb/latest/devguide/subnetgroups.html) 
1. [Install the rad CLI](https://docs.radapp.io/getting-started/)
1. Install Radius:
   ```bash
   rad install kubernetes
   ```
1. Set provider credentials to authenticate to your cloud provider (choose which type of hosting infrastructure you wish to use):
   ```bash
   # AWS
   rad credential register aws access-key --aws-access-key-id <your-aws-access-key-id> --aws-secret-access-key <your-aws-secret-access-key>

   # Azure
   rad credential register azure sp --client-id <your-azure-service-principal-client-id> --client-secret <your-azure-service-principal-client-secret> --tenant-id <your-azure-service-principal-tenant-id>
   ```
1. Clone the repository and switch to the app directory:
   ```bash
   git clone https://github.com/radius-project/samples.git
   cd samples/reference-apps/eshop
   ```
1. Deploy an environment with the proper Recipes (choose which type of hosting infrastructure you wish to use):
   ```bash
   # Containers - simply initialize a new local-dev environment
   rad init

   # Azure
   rad deploy environments/azure.bicep -p azureSubscriptionId=<your-sub-id> -p azureResourceGroup=<your-resource-group-name>

   # AWS
   rad deploy environments/aws.bicep -p awsAccountId=<your-aws-account-id> -p awsRegion=<your-aws-region> -p eksClusterName=<your-eks-cluster-name>
   ```
1. Switch to your new environment (choose which type of hosting infrastructure you wish to use):
   ```bash
   # Containers
   rad env switch default

   # Azure
   rad env switch azure

   # AWS
   rad env switch aws
   ```
1. Deploy the application:
   ```bash
   rad deploy eshop.bicep
   ```
