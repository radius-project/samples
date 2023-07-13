import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('What container orchestrator to use')
@allowed([
  'K8S'
])
param ORCHESTRATOR_TYPE string

@description('Optional App Insights Key')
param APPLICATION_INSIGHTS_KEY string

@description('Container image tag to use for eshop images')
param TAG string

@description('Name of the Gateway')
param gatewayName string

@description('Ordering SignalR Hub Http Route name')
param orderingsignalrhubHttpName string

@description('Identity Http Route name')
param identityHttpName string

@description('Web MVC Http Route name')
param webmvcHttpName string

@description('Web SPA Http Route name')
param webspaHttpName string

@description('Web Shopping Aggregator Http Route name')
param webshoppingaggHttpName string

@description('Web shopping API GW HTTP Route name')
param webshoppingapigwHttpName string

@description('Name of the Keystore Redis Link name')
param redisKeystoreName string

// CONTAINER --------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webspa
resource webspa 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'web-spa'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/webspa:${TAG}'
      env: {
        PATH_BASE: '/'
        ASPNETCORE_ENVIRONMENT: 'Production'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        CallBackUrl: '${gateway.properties.url}/'
        DPConnectionString: redisKeystore.connectionString()
        IdentityUrl: '${gateway.properties.url}/identity-api'
        IdentityUrlHC: '${identityHttp.properties.url}/hc'
        PurchaseUrl: '${gateway.properties.url}/webshoppingapigw'
        SignalrHubUrl: orderingsignalrhubHttp.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: webspaHttp.id
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: webshoppingaggHttp.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: identityHttp.id
        disableDefaultEnvVars: true
      }
      webshoppingapigw: {
        source: webshoppingapigwHttp.id
        disableDefaultEnvVars: true
      }
      orderingsignalrhub: {
        source: orderingsignalrhubHttp.id
        disableDefaultEnvVars: true
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webmvc
resource webmvc 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webmvc'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/webmvc:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webmvc'
        UseCustomizationData: 'False'
        DPConnectionString: redisKeystore.connectionString()
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        ExternalPurchaseUrl: '${gateway.properties.url}/${webshoppingapigwHttp.properties.hostname}'
        CallBackUrl: '${gateway.properties.url}/webmvc'
        IdentityUrl: '${gateway.properties.url}/identity-api'
        IdentityUrlHC: '${identityHttp.properties.url}/hc'
        PurchaseUrl: webshoppingapigwHttp.properties.url
        SignalrHubUrl: orderingsignalrhubHttp.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: webmvcHttp.id
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: webshoppingaggHttp.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: identityHttp.id
        disableDefaultEnvVars: true
      }
      webshoppingapigw: {
        source: webshoppingapigwHttp.id
        disableDefaultEnvVars: true
      }
      orderingsignalrhub: {
        source: orderingsignalrhubHttp.id
        disableDefaultEnvVars: true
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource orderingsignalrhubHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: orderingsignalrhubHttpName
}

resource identityHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityHttpName
}

resource webmvcHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webmvcHttpName
}

resource webspaHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webspaHttpName
}

resource webshoppingaggHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webshoppingaggHttpName
}

resource webshoppingapigwHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webshoppingapigwHttpName
}

// LINKS ------------------------------------------------------

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: redisKeystoreName
}
