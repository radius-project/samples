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

@description('Use Azure Service Bus for messaging')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

@description('Container image tag to use for eshop images')
param TAG string

@description('Name of the Gateway')
param gatewayName string

@description('Name of the Identity HTTP Route')
param identityHttpName string

@description('Name of the Basket HTTP Route')
param basketHttpName string

@description('The name of the Catalog HTTP Route')
param catalogHttpName string

@description('Name of the Ordering HTTP Route')
param orderingHttpName string

@description('Name of the Ordering gRPC Route')
param orderingGrpcName string

@description('Name of the Ordering SignalR Hub HTTP Route')
param orderingsignalrhubHttpName string

@description('Name of the Ordering background tasks HTTP Route')
param orderbgtasksHttpName string

@description('Name of the Keystore Redis portable resource')
param redisKeystoreName string

@description('The name of the RabbitMQ portable resource')
param rabbitmqName string

@description('Name of the Ordering SQL portable resource')
param sqlOrderingDbName string

@description('The connection string of the Azure Service Bus')
@secure()
param serviceBusConnectionString string

// CONTAINERS -------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-api
resource ordering 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'ordering-api'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/radius-project/samples/eshop/ordering.api:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        CheckUpdateTime: '30000'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: ORCHESTRATOR_TYPE
        UseLoadTest: 'False'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        'Serilog__MinimumLevel__Override__ordering-api': 'Verbose'
        PATH_BASE: '/ordering-api'
        GRPC_PORT: '81'
        PORT: '80'
        ConnectionString: sqlOrderingDb.connectionString()
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.properties.host
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: orderingHttp.id
        }
        grpc: {
          containerPort: 81
          provides: orderingGrpc.id
        }
      }
    }
    connections: {
      sql: {
        source: sqlOrderingDb.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: identityHttp.id
        disableDefaultEnvVars: true
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-backgroundtasks
resource orderbgtasks 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'ordering-backgroundtasks'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/radius-project/samples/eshop/ordering.backgroundtasks:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        CheckUpdateTime: '30000'
        GracePeriodTime: '1'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        OrchestratorType: ORCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: sqlOrderingDb.connectionString()
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.properties.host
      }
      ports: {
        http: {
          containerPort: 80
          provides: orderbgtasksHttp.id
        }
      }
    }
    connections: {
      sql: {
        source: sqlOrderingDb.id
        disableDefaultEnvVars: true
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-signalrhub
resource orderingsignalrhub 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'ordering-signalrhub'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/radius-project/samples/eshop/ordering.signalrhub:${TAG}'
      env: {
        PATH_BASE: '/payment-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.properties.host
        SignalrStoreConnectionString: '${redisKeystore.properties.host}:${redisKeystore.properties.port},password=${redisKeystore.password()},abortConnect=False'
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: orderingsignalrhubHttp.id
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: identityHttp.id
        disableDefaultEnvVars: true
      }
      ordering: {
        source: orderingHttp.id
        disableDefaultEnvVars: true
      }
      catalog: {
        source: catalogHttp.id
        disableDefaultEnvVars: true
      }
      basket: {
        source: basketHttp.id
        disableDefaultEnvVars: true
      }
    }
  }
}

// NETWORKING ------------------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

resource identityHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: identityHttpName
}

resource basketHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: basketHttpName
}

resource catalogHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: catalogHttpName
}

resource orderingHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: orderingHttpName
}

resource orderingGrpc 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: orderingGrpcName
}

resource orderingsignalrhubHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: orderingsignalrhubHttpName
}

resource orderbgtasksHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: orderbgtasksHttpName
}

// PORTABLE RESOURCES -----------------------------------------------------------

resource redisKeystore 'Applications.Datastores/redisCaches@2023-10-01-preview' existing = {
  name: redisKeystoreName
}

resource sqlOrderingDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' existing = {
  name: sqlOrderingDbName
}

resource rabbitmq 'Applications.Messaging/rabbitMQQueues@2023-10-01-preview' existing = {
  name: rabbitmqName
}
