import radius as radius

@description('The Radius application ID.')
param appId string

@description('The Dapr application ID.')
param daprPubSubBrokerName string

@description('The Dapr application ID.')
var daprAppId = 'payment-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource daprPubSubBroker 'Applications.Dapr/pubSubBrokers@2023-10-01-preview' existing = {
  name: daprPubSubBrokerName
}

//-----------------------------------------------------------------------------
// Deploy Payment API container
//-----------------------------------------------------------------------------

resource paymentApi 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'payment-api'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/payment.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
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
      pubsub: {
        source: daprPubSubBroker.id
      }
      seq: {
        source: 'http://seq:5340'
      }
    }
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = appId
output workloadIdentityId string = paymentApi.properties.identity.resource
