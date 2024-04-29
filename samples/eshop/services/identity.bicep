import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container registry to pull from, with optional path.')
param imageRegistry string

@description('Container image tag to use for eshop images')
param imageTag string

@description('Name of the Gateway')
param gatewayName string

@description('Name of the Identity SQL Database portable resource')
param sqlIdentityDbName string

@description('Name of the Keystore Redis portable resource')
param redisKeystoreName string

// CONTAINERS -------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/identity-api
resource identity 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'identity-api'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/identity.api:${imageTag}'
      env: {
        PATH_BASE: '/identity-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: 'K8S'
        IsClusterEnv: 'True'
        DPConnectionString: redisKeystore.connectionString()
        EnableDevspaces: 'False'
        ConnectionString: sqlIdentityDb.connectionString()
        MvcClient: '${gateway.properties.url}/webmvc'
        SpaClient: gateway.properties.url
        BasketApiClient: '${gateway.properties.url}/basket-api'
        OrderingApiClient: '${gateway.properties.url}/ordering-api'
        WebShoppingAggClient: '${gateway.properties.url}/webshoppingagg'
        WebhooksApiClient: '${gateway.properties.url}/webhooks-api'
        WebhooksWebClient: '${gateway.properties.url}/webhooks-client'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5105
        }
      }
      livenessProbe: {
        kind: 'httpGet'
        path: '/liveness'
        containerPort: 80
      }
      readinessProbe: {
        kind: 'httpGet'
        path: '/hc'
        containerPort: 80
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      sql: {
        source: sqlIdentityDb.id
        disableDefaultEnvVars: true
      }
      webmvc: {
        source: 'http://webmvc:5100'
        disableDefaultEnvVars: true
      }
      basket: {
        source: 'http://basket-api:5103'
        disableDefaultEnvVars: true
      }
      ordering: {
        source: 'http://ordering-api:5102'
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: 'http://webshoppingagg:5121'
        disableDefaultEnvVars: true
      }
      webhooks: {
        source: 'http://webhooks-api:5113'
        disableDefaultEnvVars: true
      }
      webhooksclient: {
        source: 'http://webhooks-client:5114'
        disableDefaultEnvVars: true
      }
    }
  }
}

// NETWORKING ------------------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

// PORTABLE RESOURCES -----------------------------------------------------------

resource sqlIdentityDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' existing = {
  name: sqlIdentityDbName
}

resource redisKeystore 'Applications.Datastores/redisCaches@2023-10-01-preview' existing = {
  name: redisKeystoreName
}

// Output
@description('Name of the Identity container')
output container string = identity.name
