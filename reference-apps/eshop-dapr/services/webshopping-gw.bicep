import radius as radius

param appId string

param catalogApiRouteName string
param catalogApiDaprRouteName string
param orderingApiRouteName string
param orderingApiDaprRouteName string
param webshoppingGwRouteName string

var daprAppId = 'webshoppingapigw'

resource catalogApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: catalogApiRouteName
}

resource catalogApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: catalogApiDaprRouteName
}

resource orderingApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: orderingApiRouteName
}

resource orderingApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: orderingApiDaprRouteName
}

resource webshoppingGwRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: webshoppingGwRouteName
}

resource webshoppingGw 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshopping-gw'
  location: 'global'
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
      catalogApiDapr: {
        source: catalogApiDaprRoute.id
      }
      orderingApi: {
        source: orderingApiRoute.id
      }
      orderingApiDapr: {
        source: orderingApiDaprRoute.id
      }
    }
  }
}
