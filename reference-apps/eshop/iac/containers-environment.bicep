import radius as rad

resource containersEShopEnv 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'containers-eshop-env'
  properties: {
    compute: {
      kind: 'kubernetes'
      resourceId: 'self'
      namespace: 'eshop'
    }
    recipes: {
      'Applications.Link/sqlDatabases': {
        containersmssql: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/containersmssql:edge'
        }
      }
      'Applications.Link/redisCaches': {
        containersredis: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/containersredis:edge'
        }
      }
      'Applications.Link/extenders': {
        containersrabbitmq: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/containersrabbitmq:edge'
        }
      }
    }
  }
}
