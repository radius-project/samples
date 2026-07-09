extension radius

@description('Azure subscription ID the environment provisions resources into.')
param azureSubscriptionId string

@description('Azure resource group the environment provisions resources into. Must already exist.')
param azureResourceGroup string

@description('Globally-unique Azure Event Hubs namespace name (6-50 alphanumerics/hyphens, starts with a letter). The workflow generates a unique value per run.')
param namespaceName string

@description('OCI ref for the Radius.Compute/containers recipe. Override to a custom build if needed; defaults to the released public recipe.')
param containersRecipe string = 'ghcr.io/radius-project/kube-recipes/containers:latest'

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'kafka-azure-avm'
  properties: {
    recipes: {
      'Radius.Messaging/kafka': {
        kind: 'bicep'

        source: 'mcr.microsoft.com/bicep/avm/res/event-hub/namespace:0.14.2'
        parameters: {
          name: namespaceName

          skuName: 'Standard'
          skuCapacity: 1

          disableLocalAuth: false

          eventhubs: [
            {
              name: '{{context.resource.properties.topic}}'
            }
          ]

          enableTelemetry: false
        }

        outputs: {
          host: 'name'
          secrets: {
            connectionString: 'primaryConnectionString'
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
