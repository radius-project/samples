import radius as radius

resource env 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'staging'
  location: 'global'
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: 'default'
    }
    recipes: {
      '': {
        linkType: 'Applications.Link/redisCaches'
        templatePath: 'rynowak.azurecr.io/recipes/redis-selfhost:latest'
      }
    }
  }
}
