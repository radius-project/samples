import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Dapr pub/sub component.')
param daprPubSubBrokerName string

@description('The name of the Dapr state store component.')
param daprStateStoreName string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The Dapr application ID.')
var daprAppId = 'basket-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

resource daprPubSubBroker 'Applications.Dapr/pubSubBrokers@2023-10-01-preview' existing = {
  name: daprPubSubBrokerName
}

resource daprStateStore 'Applications.Dapr/stateStores@2023-10-01-preview' existing = {
  name: daprStateStoreName
}

//-----------------------------------------------------------------------------
// Deploy Basket API container
//-----------------------------------------------------------------------------

resource basketApi 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'basket-api'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/basket.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        IdentityUrl: 'http://identity-api:80'
        IdentityUrlExternal: '${gateway.properties.url}/identity/'
        SeqServerUrl: 'http://seq:5340'
      }
      ports: {
        http: {
          containerPort: 80
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
        source: 'http://identity-api'
      }
      seqRoute: {
        source: 'http://seq:5340'
      }
    }
  }
}


//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = daprAppId
