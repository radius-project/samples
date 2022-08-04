import radius as radius

param applicationId string

param environment string


resource redisContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis'
  location: 'global'
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
  location: 'global'
  properties: {
    application: applicationId
    port: 6379
  }
}

resource statestore 'Applications.Connector/daprStateStores@2022-03-15-privatepreview' = {
  name: 'orders'
  location: 'global'
  properties: {
    kind:  'generic'
    type: 'state.redis'
    environment: environment
    version: 'v1'
    metadata: {
      redisHost: '${redisRoute.properties.hostname}:${redisRoute.properties.port}'
      redisPassword: ''
    }
  }
}


output statestoreID string = statestore.id
