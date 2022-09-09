import radius as radius

param appId string
param environment string

param daprPubSubBrokerName string
param paymentApiRouteName string
param seqRouteName string

var daprAppId = 'payment-api'

resource daprPubSubBroker 'Applications.Connector/daprPubSubBrokers@2022-03-15-privatepreview' existing = {
  name: daprPubSubBrokerName
}

resource paymentApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: paymentApiRouteName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource paymentApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'payment-api'
  location: 'global'
  properties: {
    application: appId
    container: {
      image: 'eshopdapr/payment.api:latest'
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
        provides: paymentApiDaprRoute.id
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

resource paymentApiDaprRoute 'Applications.Connector/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'payment-api-dapr-route'
  location: 'global'
  properties: {
    application: appId
    environment: environment
    appId: daprAppId
  }
}

output paymentApiDaprRouteName string = paymentApiDaprRoute.name
