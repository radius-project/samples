import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Blazor client HTTP route.')
param blazorClientRouteName string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource blazorClientRoute 'Applications.Core/httproutes@2023-10-01-preview' existing = {
  name: blazorClientRouteName
}

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

resource seqRoute 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Blazor client container
//-----------------------------------------------------------------------------

resource blazorClient 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'blazor-client'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/blazor.client:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApiGatewayUrlExternal: '${gateway.properties.url}/api/'
        IdentityUrlExternal: '${gateway.properties.url}/identity/'
        SeqServerUrl: seqRoute.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: blazorClientRoute.id
        }
      }
    }
    connections: {
      seqRoute: {
        source: seqRoute.id
      }
    }
  }
}
