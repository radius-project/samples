import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The Dapr application ID.')
var daprAppId = 'webshoppingagg'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

//-----------------------------------------------------------------------------
// Deploy Aggregator container
//-----------------------------------------------------------------------------

resource webshoppingAgg 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webshopping-agg'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/webshoppingagg:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        IdentityUrl: 'http://identity-api:80'
        IdentityUrlExternal: '${gateway.properties.url}/identity/'
        SeqServerUrl: 'http://seq:5340'
        BasketUrlHC: 'http://localhost:3500/v1.0/invoke/basket-api/method/hc'
        CatalogUrlHC: 'http://localhost:3500/v1.0/invoke/catalog-api/method/hc'
        IdentityUrlHC: 'http://localhost:3500/v1.0/invoke/identity-api/method/hc'
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
      identityApi: {
        source: 'http://identity-api'
      }
      seq: {
        source: 'http://seq'
      }
    }
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = daprAppId
