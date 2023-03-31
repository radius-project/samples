import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius region to deploy resources into. Only global is supported today')
@allowed([
  'global'
])
param ucpLocation string

@description('Radius application ID')
param application string

@description('What container orchestrator to use')
@allowed([
  'K8S'
])
param ORCHESTRATOR_TYPE string

@description('Optional App Insights Key')
param APPLICATION_INSIGHTS_KEY string

@description('Cotnainer image tag to use for eshop images')
param TAG string

@description('Name of the Gateway')
param gatewayName string

@description('Name of the Keystore Redis Link name')
param redisKeystoreName string

// CONTAINER --------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webspa
resource webspa 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'web-spa'
  location: ucpLocation
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
        DPConnectionString: '${redisKeystore.properties.host}:${redisKeystore.properties.port},password=${redisKeystore.password()},abortConnect=False'
        IdentityUrl: '${gateway.properties.url}/identity-api'
        IdentityUrlHC: 'http://identity-api:5105/hc'
        PurchaseUrl: '${gateway.properties.url}/webshoppingapigw'
        SignalrHubUrl: 'http://ordering-signalrhub'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5104
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: 'route(webshoppingagg)'
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'route(identity-api)'
        disableDefaultEnvVars: true
      }
      webshoppingapigw: {
        source: 'route(webshoppingapigw)'
        disableDefaultEnvVars: true
      }
      orderingsignalrhub: {
        source: 'route(ordering-signalrhub)'
        disableDefaultEnvVars: true
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webmvc
resource webmvc 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webmvc'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/webmvc:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webmvc'
        UseCustomizationData: 'False'
        DPConnectionString: '${redisKeystore.properties.host}:${redisKeystore.properties.port},password=${redisKeystore.password()},abortConnect=False'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        ExternalPurchaseUrl: '${gateway.properties.url}/webshoppingapigw'
        CallBackUrl: '${gateway.properties.url}/webmvc'
        IdentityUrl: '${gateway.properties.url}/identity-api'
        IdentityUrlHC: 'http://identity-api:5105/hc'
        PurchaseUrl: 'http://webshoppingapigw'
        SignalrHubUrl: 'http://ordering-signalrhub'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5100
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: 'route(webshoppingagg)'
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'route(identity-api)'
        disableDefaultEnvVars: true
      }
      webshoppingapigw: {
        source: 'route(webshoppingapigw)'
        disableDefaultEnvVars: true
      }
      orderingsignalrhub: {
        source: 'route(ordering-signalrhub)'
        disableDefaultEnvVars: true
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

// LINKS ------------------------------------------------------

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: redisKeystoreName
}
