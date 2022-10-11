import radius as radius

param appId string
param endpointUrl string

param identityApiRouteName string
param seqRouteName string
param webshoppingAggRouteName string

var daprAppId = 'webshoppingagg'

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource webshoppingAggRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: webshoppingAggRouteName
}

resource webshoppingAgg 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshopping-agg'
  location: 'global'
  properties: {
    application: appId
    container: {
      image: 'eshopdapr/webshoppingagg:latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        IdentityUrl: identityApiRoute.properties.url
        IdentityUrlExternal: '${endpointUrl}/identity/'
        SeqServerUrl: seqRoute.properties.url
        BasketUrlHC: 'http://localhost:3500/v1.0/invoke/basket-api/method/hc'
        CatalogUrlHC: 'http://localhost:3500/v1.0/invoke/catalog-api/method/hc'
        IdentityUrlHC: '${identityApiRoute.properties.url}/hc'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webshoppingAggRoute.id
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: daprAppId
        appPort: 80
        provides: webshoppingAggDaprRoute.id
      }
    ]
    connections: {
      identityApi: {
        source: identityApiRoute.id
      }
      seq: {
        source: seqRoute.id
      }
    }
  }
}

resource webshoppingAggDaprRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshopping-agg-dapr-route'
  location: 'global'
  properties: {
    application: appId
  }
}

output webshoppingAggDaprRouteName string = webshoppingAggDaprRoute.name

