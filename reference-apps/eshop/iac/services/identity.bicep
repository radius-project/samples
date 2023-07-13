import radius as rad

// PARAMETERS ---------------------------------------------------------

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

@description('Container image tag to use for eshop images. Defaults to linux-dotnet7')
param TAG string

@description('Name of the Gateway')
param gatewayName string

@description('Name of the Identity HTTP Route')
param identityHttpName string

@description('Name of the Basket HTTP Route')
param basketHttpName string

@description('Name of the Ordering HTTP Route')
param orderingHttpName string

@description('Name of the WebShoppingAgg HTTP Route')
param webshoppingaggHttpName string

@description('Name of the Webhooks HTTP Route')
param webhooksHttpName string

@description('Name of the WebhooksClient HTTP Route')
param webhooksclientHttpName string

@description('Name of the WebMVC HTTP Route')
param webmvcHttpName string

@description('Name of the Identity SQL Database Link')
param sqlIdentityDbName string

@description('Name of the Keystore Redis Link')
param redisKeystoreName string

// CONTAINERS -------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/identity-api
resource identity 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'identity-api'
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
        DPConnectionString: redisKeystore.connectionString()
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        XamarinCallback: ''
        EnableDevspaces: ENABLEDEVSPACES
        ConnectionString: sqlIdentityDb.connectionString()
        MvcClient: '${gateway.properties.url}/${webmvcHttp.properties.hostname}'
        SpaClient: gateway.properties.url
        BasketApiClient: '${gateway.properties.url}/${basketHttp.properties.hostname}'
        OrderingApiClient: '${gateway.properties.url}/${orderingHttp.properties.hostname}'
        WebShoppingAggClient: '${gateway.properties.url}/${webshoppingaggHttp.properties.hostname}'
        WebhooksApiClient: '${gateway.properties.url}/${webhooksHttp.properties.hostname}'
        WebhooksWebClient: '${gateway.properties.url}/${webhooksclientHttp.properties.hostname}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: identityHttp.id
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
        source: webmvcHttp.id
        disableDefaultEnvVars: true
      }
      basket: {
        source: basketHttp.id
        disableDefaultEnvVars: true
      }
      ordering: {
        source: orderingHttp.id
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: webshoppingaggHttp.id
        disableDefaultEnvVars: true
      }
      webhooks: {
        source: webhooksHttp.id
        disableDefaultEnvVars: true
      }
      webhoolsclient: {
        source: webhooksclientHttp.id
        disableDefaultEnvVars: true
      }
    }
  }
}

// NETWORKING ------------------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource identityHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityHttpName
}

resource basketHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: basketHttpName
}

resource orderingHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: orderingHttpName
}

resource webshoppingaggHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webshoppingaggHttpName
}

resource webhooksHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing =  {
  name: webhooksHttpName
}

resource webhooksclientHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webhooksclientHttpName
}

resource webmvcHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webmvcHttpName
}

// LINKS -----------------------------------------------------------

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: sqlIdentityDbName
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: redisKeystoreName
}
