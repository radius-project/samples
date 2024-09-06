extension radius

@description('Specifies the environment for resources.')
param environment string

@description('Specifies Kubernetes namespace for redis.')
param namespace string = 'default'

param frontendImage string = 'ghcr.io/radius-project/samples/dapr-frontend:latest'
param backendImage string = 'ghcr.io/radius-project/samples/dapr-backend:latest'

resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'dapr'
  properties: {
    environment: environment
  }
}

resource backend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'backend'
  properties: {
    application: app.id
    container: {
      image: backendImage
      ports: {
        web: {
          containerPort: 3000
        }
      }
    }
    connections: {
      orders: {
        source: stateStore.id
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'backend'
        appPort: 3000
      }
    ]
  }
}

resource frontend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'frontend'
  properties: {
    application: app.id
    container: {
      image: frontendImage
      env: {
        CONNECTION_BACKEND_APPID: {
          value: backend.name
        }
        ASPNETCORE_URLS: {
          value: 'http://*:8080'
        }
      }
      ports: {
        ui: {
          containerPort: 8080
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'frontend'
      }
    ]
  }
}

resource stateStore 'Applications.Dapr/stateStores@2023-10-01-preview' = {
  name: 'statestore'
  properties: {
    environment: environment
    application: app.id
    resourceProvisioning: 'manual'
    type: 'state.redis'
    version: 'v1'
    metadata: {
      redisHost: '${service.metadata.name}.${namespace}.svc.cluster.local:${service.spec.ports[0].port}'
      redisPassword: ''
    }
  }
}

extension kubernetes with {
  kubeConfig: ''
  namespace: namespace
} as kubernetes

resource statefulset 'apps/StatefulSet@v1' = {
  metadata: {
    name: 'redis'
    labels: {
      app: 'redis'
    }
  }
  spec: {
    replicas: 1
    serviceName: service.metadata.name
    selector: {
      matchLabels: {
        app: 'redis'
      }
    }
    template: {
      metadata: {
        labels: {
          app: 'redis'
        }
      }
      spec: {
        automountServiceAccountToken: true
        terminationGracePeriodSeconds: 10
        containers: [
          {
            name: 'redis'
            image: 'redis:6.2'
            securityContext: {
              allowPrivilegeEscalation: false
            }
            ports: [
              {
                containerPort: 6379
              }
            ]
          }
        ]
      }
    }
  }
}

resource service 'core/Service@v1' = {
  metadata: {
    name: 'redis'
    labels: {
      app: 'redis'
    }
  }
  spec: {
    clusterIP: 'None'
    ports: [
      {
        port: 6379
      }
    ]
    selector: {
      app: 'redis'
    }
  }
}
