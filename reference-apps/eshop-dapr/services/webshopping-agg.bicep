import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The name of the Identity API HTTP route.')
param identityApiRouteName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

@description('The name of the aggregator HTTP route.')
param webshoppingAggRouteName string

@description('The Dapr application ID.')
var daprAppId = 'webshoppingagg'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
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

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = daprAppId
