// Import Radius into your Bicep file.
import radius as radius

// The environment used by your resources for deployment.
param environment string

resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'webapp'
  properties: {
    environment: environment
  }
}

resource frontend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'frontend'
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

// Redis Cache portable resource
resource db 'Applications.Datastores/redisCaches@2023-10-01-preview' = {
  name: 'db'
  properties: {
    environment: environment
    recipe: {
      name: 'redis-kubernetes'
    }
  }
}
