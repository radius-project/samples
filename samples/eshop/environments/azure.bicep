import radius as rad

@description('The name of the Azure resource group where Azure resources will be deployed.')
param azureResourceGroup string

@description('The Azure subscription ID where Azure resources will be deployed.')
param azureSubscriptionId string

resource environment 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'azure'
  properties: {
    compute: {
      kind: 'kubernetes'
      resourceId: 'self'
      namespace: 'azure'
    }
    providers: {
      azure: {
        scope: '/subscriptions/${azureSubscriptionId}/resourceGroups/${azureResourceGroup}'
      }
    }
    recipes: {
      'Applications.Datastores/sqlDatabases': {
        default: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/recipes/azure/sqldatabases:latest'
        }
      }
      'Applications.Datastores/redisCaches': {
        default: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/recipes/azure/rediscaches:latest'
        }
      }
      'Applications.Core/extenders': {
        servicebus: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/recipes/azure/extender-servicebus:latest'
        }
      }
    }
  }
}
