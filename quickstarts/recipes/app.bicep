import radius as radius

param environment string

param location string = 'global'

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'webapp'
  location: location
  properties: {
    environment: environment
  }
}

resource frontend 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'frontend'
  location: location
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/tutorial/webapp:edge'
    }
    connections: {
      redis: {
        source: db.id
      }
    }
  }
}

// Redis Cache Link resource
resource db 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'db'
  location: location
  properties: {
    environment: environment
    mode: 'recipe'
    recipe: {
      name: 'redis-kubernetes'
    }
  }
}
