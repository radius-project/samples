extension radius

@description('The Radius Environment ID. Injected automatically by the rad CLI.')
param environment string

// Environment name derived from the Environment ID, used to keep resource names
// unique per environment (e.g. dev/test/prod) within the same resource group.
var environmentName = last(split(environment, '/'))

resource demoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'demo-${environmentName}'
  properties: {
    environment: environment
  }
}

resource demoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'demo-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    containers: {
      web: {
        image: 'ghcr.io/radius-project/samples/demo:latest'
        ports: {
          web: {
            containerPort: 3000
          }
        }
      }
    }
    connections: {
      redis: {
        source: redis.id
      }
    }
  }
}

resource redis 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    size: 'S'
  }
}

