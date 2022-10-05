import radius as radius

resource env 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'staging'
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: 'default'
    }
    recipes: {
      'Applications.Link/redisCaches': {
        default: {
          templatePath: 'rynowak.azurecr.io/recipes/redis-selfhost:0.20'
          templateKind: 'bicep'
        }
      }
    }
  }
}
