extension radius

@description('The Radius environment ID.')
param environment string

resource samplesApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'samples'
  properties: {
    environment: environment
  }
}

resource redisCache 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: samplesApp.id
    codeReference: 'samples/demo/src/db/repository.ts#L39'
    size: 'S'
  }
}

resource demoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'demo-image'
  properties: {
    environment: environment
    application: samplesApp.id
    codeReference: 'samples/demo/Dockerfile#L1'
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/demo?ref=e5e42da601083d485f4af0aeac1037878cdeff03'
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource demoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'demo'
  properties: {
    environment: environment
    application: samplesApp.id
    codeReference: 'samples/demo/src/main.ts#L53'
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
                secretName: redisCache.properties.secrets.name
                key: 'url'
              }
            }
          }
        }
        livenessProbe: {
          httpGet: {
            path: '/healthz'
            port: 3000
          }
          initialDelaySeconds: 10
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
