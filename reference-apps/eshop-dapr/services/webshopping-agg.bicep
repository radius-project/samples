import radius as radius

@description('The Radius application ID.')
param appId string

@description('The Radius environment name.')
param environment string

@description('The name of the basket API Dapr route.')
param basketApiDaprRouteName string

@description('The name of the Catalog API Dapr route.')
param catalogApiDaprRouteName string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The name of the Identity API HTTP route.')
param identityApiRouteName string

@description('The name of the Identity API Dapr route.')
param identityApiDaprRouteName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

@description('The name of the aggregator HTTP route.')
param webshoppingAggRouteName string

@description('The Dapr application ID.')
var daprAppId = 'webshoppingagg'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource basketApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: basketApiDaprRouteName
}

resource catalogApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: catalogApiDaprRouteName
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource identityApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiDaprRouteName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource webshoppingAggRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: webshoppingAggRouteName
}

//-----------------------------------------------------------------------------
// Deploy Aggregator container
//-----------------------------------------------------------------------------

resource webshoppingAgg 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshopping-agg'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/webshoppingagg:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        IdentityUrl: identityApiRoute.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/identity/'
        SeqServerUrl: seqRoute.properties.url
        BasketUrlHC: 'http://localhost:3500/v1.0/invoke/basket-api/method/hc'
        CatalogUrlHC: 'http://localhost:3500/v1.0/invoke/catalog-api/method/hc'
        IdentityUrlHC: 'http://localhost:3500/v1.0/invoke/identity-api/method/hc'
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
        provides: daprRoute.id
      }
    ]
    connections: {
      basketApiDaprRoute: {
        source: basketApiDaprRoute.id
      }
      catalogApiDaprRoute: {
        source: catalogApiDaprRoute.id
      }
      identityApi: {
        source: identityApiRoute.id
      }
      identityApiDaprRoute: {
        source: identityApiDaprRoute.id
      }
      seq: {
        source: seqRoute.id
      }
    }
  }
}

resource daprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'webshopping-agg-dapr-route'
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
