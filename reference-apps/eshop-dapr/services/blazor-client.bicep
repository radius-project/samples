import radius as radius

param appId string
param endpointUrl string

param blazorClientRouteName string
param seqRouteName string

resource blazorClientRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: blazorClientRouteName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource blazorClient 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'blazor-client'
  location: 'global'
  properties: {
    application: appId
    container: {
      image: 'eshopdapr/blazor.client:latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApiGatewayUrlExternal: '${endpointUrl}/api/'
        IdentityUrlExternal: '${endpointUrl}/identity/'
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
      seq: {
        source: seqRoute.id
      }
    }
  }
}
