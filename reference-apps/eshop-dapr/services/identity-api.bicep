import radius as radius

param appId string
param endpointUrl string

param identityApiRouteName string
param identityDbLinkName string
param seqRouteName string

@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorLoginPassword string

resource identityApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource identityDbLink 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: identityDbLinkName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource identityApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'identity-api'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/identity.api:latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/identity/'
        BlazorClientUrlExternal: endpointUrl
        IssuerUrl: '${endpointUrl}/identity/'
        ConnectionStrings__IdentityDB: 'Server=tcp:${identityDbLink.properties.server},1433;Initial Catalog=${identityDbLink.properties.database};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
        RetryMigrations: 'true'
        SeqServerUrl: seqRoute.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: identityApiRoute.id
        }
      }
    }
    connections: {
      seq: {
        source: seqRoute.id
      }
      sql: {
        source: identityDbLink.id
      }
    }
  }
}
