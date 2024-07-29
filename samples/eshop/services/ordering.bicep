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

@description('Name of the Keystore Redis portable resource')
param redisKeystoreName string

@description('Name of the Ordering SQL portable resource')
param sqlOrderingDbName string

@description('The connection string for the event bus')
@secure()
param eventBusConnectionString string

@description('Use Azure Service Bus for messaging. Allowed values: "True", "False".')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

// CONTAINERS -------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-api
resource ordering 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'ordering-api'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/ordering.api:${imageTag}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        CheckUpdateTime: '30000'
        ORCHESTRATOR_TYPE: 'K8S'
        UseLoadTest: 'False'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        'Serilog__MinimumLevel__Override__ordering-api': 'Verbose'
        PATH_BASE: '/ordering-api'
        GRPC_PORT: '81'
        PORT: '80'
        ConnectionString: sqlOrderingDb.connectionString()
        EventBusConnection: eventBusConnectionString
        identityUrl: 'http://identity-api:5105'
        IdentityUrlExternal: '${gateway.properties.url}/identity-api'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5102
        }
        grpc: {
          containerPort: 81
          port: 9102
        }
      }
    }
    connections: {
      sql: {
        source: sqlOrderingDb.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'http://identity-api:5105'
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
      image: '${imageRegistry}/ordering.backgroundtasks:${imageTag}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        CheckUpdateTime: '30000'
        GracePeriodTime: '1'
        UseLoadTest: 'False'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        ORCHESTRATOR_TYPE: 'K8S'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: sqlOrderingDb.connectionString()
        EventBusConnection: eventBusConnectionString
      }
      ports: {
        http: {
          containerPort: 80
          port: 5111
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
      image: '${imageRegistry}/ordering.signalrhub:${imageTag}'
      env: {
        PATH_BASE: '/payment-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: 'K8S'
        IsClusterEnv: 'True'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: eventBusConnectionString
        SignalrStoreConnectionString: '${redisKeystore.properties.host}:${redisKeystore.properties.port},password=${redisKeystore.password()},abortConnect=False'
        identityUrl: 'http://identity-api:5105'
        IdentityUrlExternal: '${gateway.properties.url}/identity-api'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5112
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'http://identity-api:5105'
        disableDefaultEnvVars: true
      }
      ordering: {
        source: 'http://ordering-api:5102'
        disableDefaultEnvVars: true
      }
      catalog: {
        source: 'http://catalog-api:5101'
        disableDefaultEnvVars: true
      }
      basket: {
        source: 'http://basket-api:5103'
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

resource redisKeystore 'Applications.Datastores/redisCaches@2023-10-01-preview' existing = {
  name: redisKeystoreName
}

resource sqlOrderingDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' existing = {
  name: sqlOrderingDbName
}
