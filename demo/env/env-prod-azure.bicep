import radius as radius

resource env 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'prod-azure'
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: 'default'
    }
    providers: {
      azure: {
        scope: '/subscriptions/66d1209e-1382-45d3-99bb-650e6bf63fc0/resourceGroups/rynowak-prod-azure'
      }
    }
    recipes: {
      'Applications.Link/redisCaches': {
        default: {
          templatePath: 'rynowak.azurecr.io/recipes/redis-azure:0.21'
          templateKind: 'bicep'
        }
      }
    }
  }
}
