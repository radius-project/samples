import radius as radius

param appId string
param environment string
param endpointUrl string

param basketApiRouteName string
param daprPubSubBrokerName string
param daprStateStoreName string
param identityApiRouteName string
param seqRouteName string

var daprAppId = 'basket-api'

resource basketApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: basketApiRouteName
}

resource daprPubSubBroker 'Applications.Connector/daprPubSubBrokers@2022-03-15-privatepreview' existing = {
  name: daprPubSubBrokerName
}

resource daprStateStore 'Applications.Connector/daprStateStores@2022-03-15-privatepreview' existing = {
  name: daprStateStoreName
}

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource basketApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'basket-api'
  location: 'global'
  properties: {
    application: appId
    container: {
      image: 'eshopdapr/basket.api:latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        IdentityUrl: identityApiRoute.properties.url
        IdentityUrlExternal: '${endpointUrl}/identity/'
        SeqServerUrl: seqRoute.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: basketApiRoute.id
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: daprAppId
        appPort: 80
        provides: basketApiDaprRoute.id
      }
    ]
    connections: {
      seq: {
        source: seqRoute.id
      }
      pubsub: {
        source: daprPubSubBroker.id
      }
      statestore: {
        source: daprStateStore.id
      }
    }
  }
}

resource basketApiDaprRoute 'Applications.Connector/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'basket-api-dapr-route'
  location: 'global'
  properties: {
    application: appId
    environment: environment
    appId: daprAppId
  }
}

output basketApiDaprRouteName string = basketApiDaprRoute.name
