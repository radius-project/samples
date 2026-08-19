extension radius

@description('The Radius Environment ID. Injected automatically by the rad CLI.')
param environment string

// Defaults to the published image; CI overrides this to test the freshly built image.
param image string = 'ghcr.io/radius-project/samples/demo:latest'

// Environment name derived from the Environment ID, used to keep resource names
// unique per environment (e.g. dev/test/prod) within the same resource group.
var environmentName = last(split(environment, '/'))
// Connections require a full resource ID. The environment and generated Secret
// share a Radius resource group, so retain the environment ID through that scope.
var resourceGroupId = take(environment, lastIndexOf(environment, '/providers/'))

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
        image: image
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
      redisSecret: {
        source: '${resourceGroupId}/providers/Radius.Security/secrets/${redis.properties.secrets.name}'
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
