extension radius
@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'redis-azure-app-test'
  properties: {
    environment: environment
  }
}

resource redis 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: app.id

    size: 'S'
  }
}

resource demoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'redis-demo-image'
  properties: {
    environment: environment
    application: app.id

    tag: 'demo-e2e'
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/demo?ref=190d9c4c84278980d9fae402330bd5ead76b31a5'
    }
  }
}

resource democtr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'democtr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      demo: {
        image: demoImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          CONNECTION_REDIS_URL: {
            valueFrom: {
              secretKeyRef: {
                secretName: redis.properties.secrets.name
                key: 'url'
              }
            }
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
