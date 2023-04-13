import radius as radius

@description('The Radius application ID.')
param appId string

@description('The Radius environment name.')
param environment string

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
  location: 'global'
  properties: {
    application: appId
    container: {
      image: 'amolenk/eshopondapr.payment.api:rad-latest'
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
        provides: daprRoute.id
      }
    ]
    connections: {
      seq: {
        source: seqRoute.id
      }
      pubsub: {
        source: daprPubSubBroker.id
      }
    }
  }
}

resource daprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'payment-api-dapr-route'
  location: 'global'
  properties: {
    application: appId
    environment: environment
    appId: daprAppId
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output daprRouteName string = daprRoute.name
