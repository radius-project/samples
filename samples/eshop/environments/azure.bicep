import radius as rad

@description('Azure ResourceGroup name')
param azureResourceGroup string = resourceGroup().name

@description('Azure SubscriptionId')
param azureSubscription string = subscription().subscriptionId

resource azureEShopEnv 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'azure-eshop'
  properties: {
    compute: {
      kind: 'kubernetes'
      resourceId: 'self'
      namespace: 'azure-eshop'
    }
    providers: {
      azure: {
        scope: '/subscriptions/${azureSubscription}/resourceGroups/${azureResourceGroup}'
      }
    }
    recipes: {
      'Applications.Datastores/sqlDatabases': {
        default: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/azure/sqldatabases:edge'
        }
      }
      'Applications.Datastores/redisCaches': {
        default: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/azure/rediscaches:latest'
        }
      }
      'Applications.Core/extenders': {
        servicebus: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/azure/extender-servicebus:latest'
        }
      }
    }
  }
}
