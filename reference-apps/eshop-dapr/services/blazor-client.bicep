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

resource blazorClientRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: blazorClientRouteName
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Blazor client container
//-----------------------------------------------------------------------------

resource blazorClient 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'blazor-client'
  location: 'global'
  properties: {
    application: appId
    container: {
      image: 'amolenk/eshopondapr.blazor.client:rad-latest'
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
