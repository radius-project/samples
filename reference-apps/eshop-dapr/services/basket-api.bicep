import radius as radius

@description('The Radius Application ID.')
param appId string

@description('The name of the basket API HTTP route.')
param basketApiRouteName string

@description('The name of the Dapr pub/sub component.')
param daprPubSubBrokerName string

@description('The name of the Dapr state store component.')
param daprStateStoreName string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The name of the Identity API HTTP route.')
param identityApiRouteName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

@description('The Dapr application ID.')
var daprAppId = 'basket-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource basketApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: basketApiRouteName
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource daprPubSubBroker 'Applications.Link/daprPubSubBrokers@2022-03-15-privatepreview' existing = {
  name: daprPubSubBrokerName
}

resource daprStateStore 'Applications.Link/daprStateStores@2022-03-15-privatepreview' existing = {
  name: daprStateStoreName
}

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Basket API container
//-----------------------------------------------------------------------------

resource basketApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'basket-api'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/basket.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        IdentityUrl: identityApiRoute.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/identity/'
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
      }
    ]
    connections: {
      daprPubSubBroker: {
        source: daprPubSubBroker.id
      }
      daprStateStore: {
        source: daprStateStore.id
      }
      identityApiRoute: {
        source: identityApiRoute.id
      }
      seqRoute: {
        source: seqRoute.id
      }
    }
  }
}


//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = daprAppId
