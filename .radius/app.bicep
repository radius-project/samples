extension radius

param environment string

resource demoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'demo'
  properties: {
    environment: environment
  }
}

resource redisCache 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: demoApp.id
    codeReference: 'samples/demo/src/db/redis.ts#L15'
  }
}

resource demoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'demo-image'
  properties: {
    environment: environment
    application: demoApp.id
    build: {
      source: 'git::https://github.com/nithyatsu/samples.git//samples/demo?ref=b84ba129eacac8191ef26fa118e89f5beb17f000'
      platforms: ['linux/amd64']
    }
  }
}

resource demoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'demo'
  properties: {
    environment: environment
    application: demoApp.id
    containers: {
      demo: {
        image: demoImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          PORT: {
            value: '3000'
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
        source: redisCache.id
      }
    }
  }
}
