# eShop on Dapr reference application

Visit the [Project Radius docs](https://radapp.dev/getting-started/reference-apps/eshop-dapr/) to learn more.

## Source

This reference app is a "radified" version of the [eShop on Dapr](https://github.com/dotnet-architecture/eShopOnDapr) .NET reference application.

Special thanks to [@amolenk](https://github.com/amolenk) for his implementation of eShop on Dapr (as well as the original implementation).

## Deploy

The current version of eShopOnDapr utilizes Azure Kubernetes Services to deploy and relies on various Azure resources as the infrastructure for Dapr components.

1. [Deploy an Azure Kubernetes Service cluster](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli). It's recommended to use a node VM size with 16+ GB of memory, such as the `Standard_D4_v3` size. If you use the Azure CLI to deploy the cluster, you can set the VM size using the `--node-vm-size` parameter.

2. [Install Dapr](https://docs.dapr.io/operations/hosting/kubernetes/kubernetes-deploy/)
3. [Install the rad CLI](https://radapp.dev/getting-started/)
4. [Initialize a new Radius environment](https://radapp.dev/getting-started/)
5. Clone the repository and switch to the app directory:

   ```bash
   git clone https://github.com/project-radius/samples.git
   cd samples/reference-apps/eshop-dapr
   ```

6. Get the principal ID of the user-assigned managed identity for the AKS cluster:

   ```bash
   az aks show -g <aks-resource-group> -n <aks-name> --query identityProfile.kubeletidentity.objectId -o tsv
   ```

7. Deploy the app:

   ```bash
   rad deploy main.bicep -p sqlAdministratorLoginPassword=<choose-a-password> -p aksPrincipalId=<principalId>
   ```

## Endpoints

- Main UI: `http://gateway.eshopondapr.<aks-external-ip>.nip.io`
- Health status: `http://gateway.eshopondapr.<aks-external-ip>.nip.io/health`
- Logs: `http://gateway.eshopondapr.<aks-external-ip>.nip.io/log/`
