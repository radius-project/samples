extension radius

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
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        UseCustomizationData: {
          value: 'False'
        }
        AzureServiceBusEnabled: {
          value: AZURESERVICEBUSENABLED
        }
        CheckUpdateTime: {
          value: '30000'
        }
        ORCHESTRATOR_TYPE: {
          value: 'K8S'
        }
        UseLoadTest: {
          value: 'False'
        }
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': {
          value: 'Verbose'
        }
        'Serilog__MinimumLevel__Override__ordering-api': {
          value: 'Verbose'
        }
        PATH_BASE: {
          value: '/ordering-api'
        }
        GRPC_PORT: {
          value: '81'
        }
        PORT: {
          value: '80'
        }
        ConnectionString: {
          value: sqlOrderingDb.listSecrets().connectionString
        }
        EventBusConnection: {
          value: eventBusConnectionString
        }
        identityUrl: {
          value: 'http://identity-api:5105'
        }
        IdentityUrlExternal: {
          value: '${gateway.properties.url}/identity-api'
        }
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
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        UseCustomizationData: {
          value: 'False'
        }
        CheckUpdateTime: {
          value: '30000'
        }
        GracePeriodTime: {
          value: '1'
        }
        UseLoadTest: {
          value: 'False'
        }
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': {
          value: 'Verbose'
        }
        ORCHESTRATOR_TYPE: {
          value: 'K8S'
        }
        AzureServiceBusEnabled: {
          value: AZURESERVICEBUSENABLED
        }
        ConnectionString: {
          value: sqlOrderingDb.listSecrets().connectionString
        }
        EventBusConnection: {
          value: eventBusConnectionString
        }
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
        PATH_BASE: {
          value: '/payment-api'
        }
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        OrchestratorType: {
          value: 'K8S'
        }
        IsClusterEnv: {
          value: 'True'
        }
        AzureServiceBusEnabled: {
          value: AZURESERVICEBUSENABLED
        }
        EventBusConnection: {
          value: eventBusConnectionString
        }
        SignalrStoreConnectionString: {
          value: '${redisKeystore.properties.host}:${redisKeystore.properties.port},password=${redisKeystore.listSecrets().password},abortConnect=False'
        }
        identityUrl: {
          value: 'http://identity-api:5105'
        }
        IdentityUrlExternal: {
          value: '${gateway.properties.url}/identity-api'
        }
      }
      ports: {
        http: {
          containerPort: 80
          port: 5112
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
