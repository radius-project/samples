import radius as radius

@description('The Radius Application ID.')
param appId string

@description('The name of the Payment API HTTP route.')
param paymentApiRouteName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

@description('The Dapr application ID.')
param daprPubSubBrokerName string

@description('The Dapr application ID.')
var daprAppId = 'payment-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource daprPubSubBroker 'Applications.Link/daprPubSubBrokers@2022-03-15-privatepreview' existing = {
  name: daprPubSubBrokerName
}

resource paymentApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: paymentApiRouteName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Payment API container
//-----------------------------------------------------------------------------

resource paymentApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'payment-api'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/payment.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        SeqServerUrl: seqRoute.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: paymentApiRoute.id
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
        source: seqRoute.id
      }
    }
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = appId
output workloadIdentityId string = paymentApi.properties.identity.resource
