import radius as radius

param environment string

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'dapr-quickstart'
  location: 'global'
  properties: {
    environment: environment
  }
}

resource backend 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'backend'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/quickstarts/dapr-backend:0.13'
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
        provides: backendRoute.id
        appId: 'backend'
        appPort: 3000
      }
    ]
  }
}

resource backendRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'backend-route'
  location: 'global'
  properties: {
    environment: environment
    application: app.id
    appId: 'backend'
  }
}

resource frontend 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'frontend'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/quickstarts/dapr-frontend:0.13'
      ports: {
        ui: {
          containerPort: 80
          provides: frontendRoute.id
        }
      }
    }
    connections: {
      backend: {
        source: backendRoute.id
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

resource frontendRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' = {
  name: 'frontend-route'
  location: 'global'
  properties: {
    application: app.id
  }
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'gateway'
  location: 'global'
  properties: {
    application: app.id
    routes: [
      {
        path: '/'
        destination: frontendRoute.id
      }
    ]
  }
}

resource stateStore 'Applications.Link/daprStateStores@2022-03-15-privatepreview' = {
  name: 'statestore'
  location: 'global'
  properties: {
    environment: environment
    application: app.id
    mode: 'values'
    type: 'state.redis'
    version: 'v1'
    metadata: {
      redisHost: '${service.metadata.name}:${service.spec.ports[0].port}'
      redisPassword: ''
    }
  }
}

import kubernetes as kubernetes{
  kubeConfig: ''
  namespace: 'default'
}

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
