extension radius

@description('Azure subscription ID the environment provisions resources into.')
param azureSubscriptionId string

@description('Azure resource group the environment provisions resources into. Must already exist.')
param azureResourceGroup string

@description('Globally-unique Cosmos DB account name (3-44 lowercase alphanumerics/hyphens). The workflow generates a unique value per run.')
param accountName string

@description('OCI ref for the Radius.Compute/containers recipe. Override to a custom build if needed; defaults to the released public recipe.')
param containersRecipe string = 'ghcr.io/radius-project/kube-recipes/containers:latest'

@description('Optional public IP allowed through the Cosmos DB account firewall — the CI runner egress IP, which the in-cluster mongo-express container also NATs through. The app-connection workflow computes it at provision time and enables public network access for it; the provisioning-only workflow leaves it empty (public access stays disabled, matching the AVM default, since that tier only checks the account exists).')
param clientIpAddress string = ''

@description('OCI registry the containerImages recipe builds and pushes the mongo-express image to (e.g. `ghcr.io/myorg`).')
param containerImagesRegistry string

@description('Kubernetes Secret (in the environment namespace) holding the push registry `username`/`password`.')
param containerImagesRegistrySecretName string

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'mongodb-azure-avm'
  properties: {
    recipes: {
      'Radius.Data/mongoDatabases': {
        kind: 'bicep'

        source: 'mcr.microsoft.com/bicep/avm/res/document-db/database-account:0.19.0'
        parameters: {
          name: accountName
          capabilitiesToAdd: [
            'EnableMongo'
          ]
          mongodbDatabases: [
            {
              name: '{{context.resource.properties.database}}'
            }
          ]

          networkRestrictions: empty(clientIpAddress) ? {
            ipRules: []
            publicNetworkAccess: 'Disabled'
          } : {
            ipRules: [
              clientIpAddress
            ]
            networkAclBypass: 'AzureServices'
            publicNetworkAccess: 'Enabled'
          }

          enableTelemetry: false
        }

        outputs: {
          endpoint: 'endpoint'
          secrets: {
            connectionString: 'primaryReadWriteConnectionString'
          }
        }
      }

      'Radius.Compute/containers': {
        kind: 'bicep'
        source: containersRecipe
      }

      'Radius.Security/secrets': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/secrets:latest'
      }

      'Radius.Compute/containerImages': {
        kind: 'terraform'
        source: 'git::https://github.com/radius-project/resource-types-contrib.git//Compute/containerImages/recipes/kubernetes/terraform?ref=b9e0fad536a53349b98f94c5be961db84845e1b7'
        parameters: {
          registry: containerImagesRegistry
          registrySecretName: containerImagesRegistrySecretName
        }
      }
    }
  }
}

resource env 'Radius.Core/environments@2025-08-01-preview' = {
  name: 'azure'
  properties: {
    providers: {
      azure: {
        subscriptionId: azureSubscriptionId
        resourceGroupName: azureResourceGroup
      }

      kubernetes: {
        namespace: 'default'
      }
    }
    recipePacks: [
      recipes.id
    ]
  }
}
