import radius as radius

param appId string
param radEnvironment string
param endpointUrl string

param daprPubSubBrokerName string
param identityApiRouteName string
param orderingApiRouteName string
param orderingDbConnectorName string
param seqRouteName string

@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorLoginPassword string

var daprAppId = 'ordering-api'

resource daprPubSubBroker 'Applications.Connector/daprPubSubBrokers@2022-03-15-privatepreview' existing = {
  name: daprPubSubBrokerName
}

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource orderingApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: orderingApiRouteName
}

resource orderingDbConnector 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: orderingDbConnectorName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource orderingApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-api'
  location: 'global'
  properties: {
    application: appId
    container: {
      image: 'eshopdapr/ordering.api:latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ConnectionStrings__OrderingDB: 'Server=tcp:${orderingDbConnector.properties.server},1433;Initial Catalog=${orderingDbConnector.properties.database};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
        IdentityUrl: identityApiRoute.properties.url
        IdentityUrlExternal: '${endpointUrl}/identity/'
        RetryMigrations: 'true'
        SeqServerUrl: seqRoute.properties.url
        SendConfirmationEmail: 'false'
      }
      ports: {
        http: {
          containerPort: 80
          provides: orderingApiRoute.id
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: daprAppId
        appPort: 80
        provides: orderingApiDaprRoute.id
      }
    ]
    connections: {
      seq: {
        source: seqRoute.id
      }
      sql: {
        source: orderingDbConnector.id
      }
      pubsub: {
        source: daprPubSubBroker.id
      }
    }
  }
}

resource orderingApiDaprRoute 'Applications.Connector/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'ordering-api-dapr-route'
  location: 'global'
  properties: {
    application: appId
    environment: radEnvironment
    appId: daprAppId
  }
}

output orderingApiDaprRouteName string = orderingApiDaprRoute.name
