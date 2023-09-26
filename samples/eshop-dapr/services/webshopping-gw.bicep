import radius as radius

param appId string

var daprAppId = 'webshoppingapigw'

resource webshoppingGw 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webshopping-gw'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/webshoppingapigw:rad-latest'
      env: {
        ENVOY_CATALOG_API_ADDRESS: 'catalog-api'
        ENVOY_CATALOG_API_PORT: '80'
        ENVOY_ORDERING_API_ADDRESS: 'ordering-api'
        ENVOY_ORDERING_API_PORT: '80'
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
      catalogApi: {
        source: 'http://catalog-api:80'
      }
      orderingApi: {
        source: 'http://ordering-api:80'
      }
    }
  }
}
