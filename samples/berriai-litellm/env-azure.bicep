extension radius

@description('Azure subscription ID the environment provisions resources into.')
param azureSubscriptionId string

@description('Azure resource group the environment provisions resources into. Must already exist.')
param azureResourceGroup string

@description('Globally-unique Azure OpenAI account name (2-64 alphanumerics/hyphens). The workflow generates a unique value per run.')
param accountName string

@description('OCI ref for the Radius.Compute/containers recipe. Override to a custom build if needed; defaults to the released public recipe.')
param containersRecipe string = 'ghcr.io/radius-project/kube-recipes/containers:latest'

@description('OCI registry the containerImages recipe builds and pushes the LiteLLM image to (e.g. `ghcr.io/myorg`).')
param containerImagesRegistry string

@description('Kubernetes Secret (in the environment namespace) holding the push registry `username`/`password`.')
param containerImagesRegistrySecretName string

@description('Git source for the containerImages Terraform recipe. Defaults to a reproducible upstream revision.')
param containerImagesRecipe string = 'git::https://github.com/radius-project/resource-types-contrib.git//Compute/containerImages/recipes/kubernetes/terraform?ref=b9e0fad536a53349b98f94c5be961db84845e1b7'

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'llm-azure-avm'
  properties: {
    recipes: {
      'Radius.AI/models': {
        kind: 'bicep'

        source: 'mcr.microsoft.com/bicep/avm/res/cognitive-services/account:0.15.0'
        parameters: {
          name: accountName
          kind: 'OpenAI'
          sku: 'S0'
          customSubDomainName: accountName

          disableLocalAuth: false

          publicNetworkAccess: 'Enabled'
          deployments: [
            {
              name: 'chat'
              model: {
                format: 'OpenAI'
                name: '{{context.resource.properties.model}}'
                version: '2025-08-07'
              }
              sku: {
                name: 'GlobalStandard'
                capacity: 1
              }
            }
          ]

          enableTelemetry: false
        }

        outputs: {
          endpoint: 'endpoint'
          secrets: {
            apiKey: 'primaryKey'
          }
        }
      }

      'Radius.Compute/containers': {
        kind: 'bicep'
        source: containersRecipe
      }

      'Radius.Compute/containerImages': {
        kind: 'terraform'
        source: containerImagesRecipe
        parameters: {
          registry: containerImagesRegistry
          registrySecretName: containerImagesRegistrySecretName
        }
      }

      'Radius.Security/secrets': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/secrets:latest'
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
