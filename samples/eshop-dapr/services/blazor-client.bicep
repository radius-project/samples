import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Radius gateway.')
param gatewayName string


//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

//-----------------------------------------------------------------------------
// Deploy Blazor client container
//-----------------------------------------------------------------------------

resource blazorClient 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'blazor-client'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/blazor.client:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApiGatewayUrlExternal: '${gateway.properties.url}/api/'
        IdentityUrlExternal: '${gateway.properties.url}/identity/'
        SeqServerUrl: 'http://seq:5340'
      }
      ports: {
        http: {
          containerPort: 80
        }
      }
    }
    connections: {
      seqRoute: {
        source: 'http://seq:5340'
      }
    }
  }
}
