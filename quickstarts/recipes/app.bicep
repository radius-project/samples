// Import Radius into your Bicep file.
import radius as radius

// The environment used by your resources for deployment.
param environment string

// The location property defines where to deploy a resource within the targeted platform.
// For self-hosted environments, the location property must be set to 'global' to indicate the resource is scoped to the entire underlying cluster. 
@allowed([
  'global'
])
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
