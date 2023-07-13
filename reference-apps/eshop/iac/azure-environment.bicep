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
      namespace: 'eshop'
    }
    providers: {
      azure: {
        scope: '/subscriptions/${azureSubscription}/resourceGroups/${azureResourceGroup}'
      }
    }
    recipes: {
      'Applications.Link/sqlDatabases': {
        azuremssql: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/azuremssql:edge'
        }
      }
      'Applications.Link/redisCaches': {
        azureredis: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/azureredis:edge'
        }
      }
      'Applications.Link/extenders': {
        containersmessagequeue: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/containersrabbitmq:edge'
        }
      }
    }
  }
}
