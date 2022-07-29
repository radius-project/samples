import radius as radius

param location string = resourceGroup().location
param environment string

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'dapr-quickstart'
  location: location
  properties: {
    environment: environment
  }
}

resource backend 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'backend'
  location: location
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/daprtutorial-backend:latest'
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

resource backendRoute 'Applications.Connector/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'backend-route'
  location: location
  properties: {
    environment: environment
    application: app.id
    appId: 'backend'
  }
}

resource frontend 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'frontend'
  location: location
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/daprtutorial-frontend:latest'
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
  location: location
  properties: {
    application: app.id
  }
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'gateway'
  location: location
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

resource redisContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis-container'
  location: location
  properties: {
    application: app.id
    container: {
      image: 'redis:6.2'
      ports: {
        redis: {
          containerPort: 6379
          provides: redisRoute.id
        }
      }
    }
  }
}

resource redisRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' = {
  name: 'redis-route'
  location: location
  properties: {
    application: app.id
    port: 6379
  }
}

resource stateStore 'Applications.Connector/daprStateStores@2022-03-15-privatepreview' = {
  name: 'statestore'
  location: location
  properties: {
    environment: environment
    application: app.id
    kind: 'generic'
    type: 'state.redis'
    version: 'v1'
    metadata: {
      redisHost: '${redisRoute.properties.hostname}:${redisRoute.properties.port}'
      redisPassword: ''
    }
  }
}
