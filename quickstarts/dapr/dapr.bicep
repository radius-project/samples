import radius as radius

param location string = resourceGroup().location
param environment string

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'dapr-hello'
  location: location
  properties: {
    environment: environment
  }
}

resource nodeapplication_dapr 'Applications.Connector/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'nodeapp'
  location: location
  properties: {
    environment: environment
    application: app.id
    appId: 'nodeapp'
  }
}

resource nodeapplication 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'nodeapp'
  location: location
  properties: {
    application: app.id
    container: {
      image: 'radiusteam/tutorial-nodeapp'
      ports: {
        web: {
          containerPort: 3000
        }
      }
    }
    connections: {
      statestore: {
        source: statestore.id
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        provides: nodeapplication_dapr.id
        appId: 'nodeapp'
        appPort: 3000
      }
    ]
  }
}

resource pythonapplication 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'pythonapp'
  location: location
  properties: {
    application: app.id
    connections: {
      nodeapp: {
        source: nodeapplication_dapr.id
      }
    }
    container: {
      image: 'radiusteam/tutorial-pythonapp'
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'pythonapp'
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

resource statestore 'Applications.Connector/daprStateStores@2022-03-15-privatepreview' = {
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
