# eShop on Dapr reference application

Visit the [Radius docs](https://docs.radapp.io/tutorials/eshop/) to learn more.

## Source

This reference app is a "radified" version of the [eShop on Dapr](https://github.com/dotnet-architecture/eShopOnDapr) .NET reference application.

Special thanks to [@amolenk](https://github.com/amolenk) for his implementation of eShop on Dapr (as well as the original implementation).

## Deploy

The current version of eShopOnDapr utilizes Azure Kubernetes Services to deploy and relies on various Azure resources as the infrastructure for Dapr components.

1. [Deploy an Azure Kubernetes Service cluster](https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-cli). It's recommended to use a node VM size with 16+ GB of memory, such as the `Standard_D4_v3` size. If you use the Azure CLI to deploy the cluster, you can set the VM size using the `--node-vm-size` parameter.

1. [Enable an OIDC Connector provider on AKS cluster](https://learn.microsoft.com/en-us/azure/aks/use-oidc-issuer)

1. [Install Azure AD Workload Identity](https://azure.github.io/azure-workload-identity/docs/installation.html)

1. Install the Dapr '1.11.0-rc.4' or later version to get Dapr support for Azure AD Workload Identity:

   ```bash
   helm repo add dapr https://dapr.github.io/helm-charts/
   helm repo update
   kubectl create namespace dapr-system
   helm install dapr dapr/dapr --namespace dapr-system --version 1.11.0-rc.4
   ```

1. [Install the rad CLI](https://docs.radapp.io/getting-started/)

1. [Initialize a new Radius environment](https://docs.radapp.io/getting-started/)

1. Clone the repository and switch to the app directory:

   ```bash
   git clone https://github.com/radius-project/samples.git
   cd samples/reference-apps/eshop-dapr
   ```

1. Get the Azure AD Workload Identity OIDC Issuer URL:

   ```bash
   az aks show -n <cluster-name> -g <resource-group> --query "oidcIssuerProfile.issuerUrl" -otsv
   ```

1. Deploy the app:

   ```bash
   rad deploy main.bicep -p oidcIssuer=<OIDC Issuer URL>
   ```

## Endpoints

- Main UI: `http://gateway.eshopondapr.<aks-external-ip>.nip.io`
- Health status: `http://gateway.eshopondapr.<aks-external-ip>.nip.io/health`
- Logs: `http://gateway.eshopondapr.<aks-external-ip>.nip.io/log/`
