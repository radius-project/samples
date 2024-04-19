import radius as radius

param applicationId string

param environment string

resource redisContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis'
  properties: {
    application: applicationId
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
  properties: {
    application: applicationId
    port: 6379
  }
}

resource statestore 'Applications.Link/daprStateStores@2022-03-15-privatepreview' = {
  name: 'orders'
  properties: {
    resourceProvisioning: 'manual'
    type: 'state.redis'
    application: applicationId
    environment: environment
    version: 'v1'
    metadata: {
      //       redisHost: '${service.metadata.name}.${namespace}.svc.cluster.local:${service.spec.ports[0].port}'
      redisHost: '${redisRoute.properties.hostname}:${redisRoute.properties.port}'
      redisPassword: ''
    }
  }
}


output statestoreID string = statestore.id
