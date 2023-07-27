import radius as rad

resource containersEShopEnv 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'containers-eshop-env'
  properties: {
    compute: {
      kind: 'kubernetes'
      resourceId: 'self'
      namespace: 'containers-eshop'
    }
    recipes: {
      'Applications.Link/sqlDatabases': {
        sqldatabase: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/local-dev/sqldatabases:edge'
        }
      }
      'Applications.Link/redisCaches': {
        rediscache: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/local-dev/rediscaches:edge'
        }
      }
      'Applications.Link/extenders': {
        rabbitmqmessagequeue: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/local-dev/rabbitmqmessagequeues:edge'
        }
      }
    }
  }
}
