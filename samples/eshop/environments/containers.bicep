import radius as rad

resource containersEShopEnv 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'containers-eshop-env'
  properties: {
    compute: {
      kind: 'kubernetes'
      resourceId: 'self'
      namespace: 'containers-eshop'
    }
    recipes: {
      'Applications.Datastores/sqlDatabases': {
        sqldatabase: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/local-dev/sqldatabases:edge'
        }
      }
      'Applications.Datastores/redisCaches': {
        rediscache: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/local-dev/rediscaches:edge'
        }
      }
      'Applications.Messaging/rabbitMQQueues': {
        rabbitmqmessagequeue: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/local-dev/rabbitmqmessagequeues:edge'
        }
      }
    }
  }
}
