import radius as radius

param appId string

param catalogApiRouteName string
param orderingApiRouteName string
param webshoppingGwRouteName string

var daprAppId = 'webshoppingapigw'

resource catalogApiRoute 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: catalogApiRouteName
}

resource orderingApiRoute 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: orderingApiRouteName
}

resource webshoppingGwRoute 'Applications.Core/httproutes@2023-10-01-preview' existing = {
  name: webshoppingGwRouteName
}

resource webshoppingGw 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webshopping-gw'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/webshoppingapigw:rad-latest'
      env: {
        ENVOY_CATALOG_API_ADDRESS: catalogApiRoute.properties.hostname
        ENVOY_CATALOG_API_PORT: '${catalogApiRoute.properties.port}'
        ENVOY_ORDERING_API_ADDRESS: orderingApiRoute.properties.hostname
        ENVOY_ORDERING_API_PORT: '${orderingApiRoute.properties.port}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webshoppingGwRoute.id
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
        source: catalogApiRoute.id
      }
      orderingApi: {
        source: orderingApiRoute.id
      }
    }
  }
}
