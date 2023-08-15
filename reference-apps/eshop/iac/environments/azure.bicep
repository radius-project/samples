import radius as rad

@description('Azure ResourceGroup name')
param azureResourceGroup string = resourceGroup().name

@description('Azure SubscriptionId')
param azureSubscription string = subscription().subscriptionId

resource azureEShopEnv 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'azure-eshop-env'
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
      'Applications.Link/sqlDatabases': {
        sqldatabase: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/azure/sqldatabases:latest'
        }
      }
      'Applications.Link/redisCaches': {
        rediscache: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/azure/rediscaches:latest'
        }
      }
      'Applications.Link/extenders': {
        servicebus: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/azure/extender-servicebus:latest'
        }
      }
    }
  }
}
