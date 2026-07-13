extension radius

@description('Azure subscription ID the environment provisions resources into.')
param azureSubscriptionId string

@description('Azure resource group the environment provisions resources into. Must already exist.')
param azureResourceGroup string

@description('Globally-unique Azure Managed Redis (Redis Enterprise) cluster name (1-60 alphanumerics/hyphens, starts/ends with a letter or number). The workflow generates a unique value per run.')
param cacheName string

@description('OCI ref for the Radius.Compute/containers recipe. Override to a custom build if needed; defaults to the released public recipe.')
param containersRecipe string = 'ghcr.io/radius-project/kube-recipes/containers:latest'

@description('OCI registry the containerImages recipe builds and pushes the demo image to (e.g. `ghcr.io/myorg`).')
param containerImagesRegistry string

@description('Kubernetes Secret (in the environment namespace) holding the push registry `username`/`password`.')
param containerImagesRegistrySecretName string

@description('Git source for the containerImages Terraform recipe. Defaults to a reproducible upstream revision.')
param containerImagesRecipe string = 'git::https://github.com/radius-project/resource-types-contrib.git//Compute/containerImages/recipes/kubernetes/terraform?ref=7f5375bf89305d7641ff645336841618b305daf8'

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'redis-azure-avm'
  properties: {
    recipes: {
      'Radius.Data/redisCaches': {
        kind: 'bicep'

        source: 'mcr.microsoft.com/bicep/avm/res/cache/redis-enterprise:0.5.1'
        parameters: {
          name: cacheName

          skuName: '{{context.resource.properties.size == "S" ? "Balanced_B0" : "Balanced_B1"}}'

          highAvailability: 'Disabled'

          database: {
            name: 'default'
            accessKeysAuthentication: 'Enabled'
          }

          publicNetworkAccess: 'Enabled'

          enableTelemetry: false
        }

        outputs: {
          host: 'hostName'
          port: 'port'
          secrets: {
            url: 'primaryConnectionString'
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
        source: containerImagesRecipe
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
