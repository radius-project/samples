extension radius

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
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        ApiGatewayUrlExternal: {
          value: '${gateway.properties.url}/api/'
        }
        IdentityUrlExternal: {
          value: '${gateway.properties.url}/identity/'
        }
        SeqServerUrl: {
          value: 'http://seq:5340'
        }
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
