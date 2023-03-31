import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius region to deploy resources into. Only global is supported today')
@allowed([
  'global'
])
param ucpLocation string

@description('Radius application ID')
param application string

@description('Optional App Insights Key')
param APPLICATION_INSIGHTS_KEY string

@description('Use dev spaces')
@allowed([
  'True'
  'False'
])
param ENABLEDEVSPACES string

@description('Cotnainer image tag to use for eshop images. Defaults to linux-dotnet7')
param TAG string

@description('SQL administrator username')
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

@description('Name of the Gateway')
param gatewayName string

@description('Name of the Identity SQL Database Link')
param sqlIdentityDbName string

@description('Name of the Keystore Redis Link')
param redisKeystoreName string

// CONTAINERS -------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/identity-api
resource identity 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'identity-api'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/identity.api:${TAG}'
      env: {
        PATH_BASE: '/identity-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: 'K8S'
        IsClusterEnv: 'True'
        DPConnectionString: '${redisKeystore.properties.host}:${redisKeystore.properties.port},password=${redisKeystore.password()},abortConnect=False'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        XamarinCallback: ''
        EnableDevspaces: ENABLEDEVSPACES
        ConnectionString: 'Server=tcp:${sqlIdentityDb.properties.server},1433;Initial Catalog=${sqlIdentityDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
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
        source: 'route(webmvc)'
        disableDefaultEnvVars: true
      }
      basket: {
        source: 'route(basket-api)'
        disableDefaultEnvVars: true
      }
      ordering: {
        source: 'route(ordering-api)'
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: 'route(webshoppingagg)'
        disableDefaultEnvVars: true
      }
      webhooks: {
        source:'route(webhooks-api)'
        disableDefaultEnvVars: true
      }
      webhoolsclient: {
        source: 'routes(webhooks-client)'
        disableDefaultEnvVars: true
      }
    }
  }
}

// NETWORKING ------------------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

// LINKS -----------------------------------------------------------

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: sqlIdentityDbName
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: redisKeystoreName
}
