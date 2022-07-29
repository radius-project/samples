import radius as radius

param appId string
param environment string
param location string

param catalogApiRouteName string
param catalogDbConnectorName string
param daprPubSubBrokerName string
param seqRouteName string

@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorLoginPassword string

var daprAppId = 'catalog-api'

resource catalogApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: catalogApiRouteName
}

resource catalogDbConnector 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: catalogDbConnectorName
}

resource daprPubSubBroker 'Applications.Connector/daprPubSubBrokers@2022-03-15-privatepreview' existing = {
  name: daprPubSubBrokerName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource catalogApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'catalog-api'
  location: location
  properties: {
    application: appId
    container: {
      image: 'eshopdapr/catalog.api:latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ConnectionStrings__CatalogDB: 'Server=tcp:${catalogDbConnector.properties.server},1433;Initial Catalog=${catalogDbConnector.properties.database};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
        RetryMigrations: 'true'
        SeqServerUrl: seqRoute.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: catalogApiRoute.id
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: daprAppId
        appPort: 80
        provides: catalogApiDaprRoute.id
      }
    ]
    connections: {
      seq: {
        source: seqRoute.id
      }
      sql: {
        source: catalogDbConnector.id
      }
      pubsub: {
        source: daprPubSubBroker.id
      }
    }
  }
}

resource catalogApiDaprRoute 'Applications.Connector/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'catalog-api-dapr-route'
  location: location
  properties: {
    application: appId
    environment: environment
    appId: daprAppId
  }
}

output catalogApiDaprRouteName string = catalogApiDaprRoute.name
