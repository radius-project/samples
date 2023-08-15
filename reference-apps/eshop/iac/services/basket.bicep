import radius as rad

// Parameters ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container image tag to use for eshop images')
param TAG string

@description('Optional App Insights Key')
param APPLICATION_INSIGHTS_KEY string

@description('What container orchestrator to use')
@allowed([
  'K8S'
])
param ORCHESTRATOR_TYPE string

@description('Use Azure Service Bus for messaging')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

@description('The name of the Radius Gateway')
param gatewayName string

@description('The name of the Identity HTTP Route')
param identityHttpName string

@description('The name of the Basket HTTP Route')
param basketHttpName string

@description('The name of the Basket gRPC Route')
param basketGrpcName string

@description('The name of the Redis Basket Link')
param redisBasketName string

@description('The connection string for the event bus')
@secure()
param eventBusConnectionString string

// Container -------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/basket-api
resource basket 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'basket-api'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/basket.api:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        PATH_BASE: '/basket-api'
        OrchestratorType: ORCHESTRATOR_TYPE
        PORT: '80'
        GRPC_PORT: '81'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: redisBasket.connectionString()
        EventBusConnection: eventBusConnectionString
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: basketHttp.id
        }
        grpc: {
          containerPort: 81
          provides: basketGrpc.id
        }
      }
    }
    connections: {
      redis: {
        source: redisBasket.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: identityHttp.id
        disableDefaultEnvVars: true
      }
    }
  }
}

// Networking -------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource identityHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityHttpName
}

resource basketHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: basketHttpName
}

resource basketGrpc 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: basketGrpcName
}

// Links ------------------------------------------

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: redisBasketName
}
