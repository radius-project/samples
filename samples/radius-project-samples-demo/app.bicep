extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

param buildSource string = 'git::https://github.com/radius-project/samples.git//samples/demo?ref=190d9c4c84278980d9fae402330bd5ead76b31a5'

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'redis-demo'
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

resource image 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'image'
  properties: {
    environment: environment
    application: app.id
    build: {
      source: buildSource
      platforms: ['linux/amd64']
    }
  }
}

resource web 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'web'
  properties: {
    environment: environment
    application: app.id
    containers: {
      demo: {
        image: image.properties.imageReference
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
        readinessProbe: {
          httpGet: {
            path: '/healthz'
            port: 3000
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
