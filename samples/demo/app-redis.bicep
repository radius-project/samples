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

resource redis 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    size: 'S'
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
        // The recipe's `url` secret is NOT injected through the connection. It is
        // materialized into a managed Radius.Security/secrets resource, so bind it
        // by reference with secretKeyRef -- the value never lands in the pod spec.
        env: {
          REDIS_URL: {
            valueFrom: {
              secretKeyRef: {
                secretName: redis.properties.secrets.name
                key: 'url'
              }
            }
          }
        }
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
