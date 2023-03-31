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

@description('Use Azure Service Bus for messaging')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

@description('Cotnainer image tag to use for eshop images')
param TAG string

@description('SQL administrator username')
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

@description('Name of the Gateway')
param gatewayName string

@description('Name of the Keystore Redis Link')
param redisKeystoreName string

@description('The name of the RabbitMQ Link')
param rabbitmqName string

@description('Name of the Ordering SQL Link')
param sqlOrderingDbName string

@description('The connection string of the Azure Service Bus')
@secure()
param serviceBusConnectionString string

// CONTAINERS -------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-api
resource ordering 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-api'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/ordering.api:${TAG}'
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
        ConnectionString: 'Server=tcp:${sqlOrderingDb.properties.server},1433;Initial Catalog=${sqlOrderingDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.connectionString()
        identityUrl: 'http://identity-api:5105'
        IdentityUrlExternal: '${gateway.properties.url}/identity-api'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5102
          scheme: 'http'
        }
        grpc: {
          containerPort: 81
          port: 9102
          scheme: 'http'
        }
      }
    }
    connections: {
      sql: {
        source: sqlOrderingDb.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'route(identity-api)'
        disableDefaultEnvVars: true
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-backgroundtasks
resource orderbgtasks 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-backgroundtasks'
  location: 'global'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/ordering.backgroundtasks:${TAG}'
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
        ConnectionString: 'Server=tcp:${sqlOrderingDb.properties.server},1433;Initial Catalog=${sqlOrderingDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.connectionString()
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
resource orderingsignalrhub 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-signalrhub'
  location: 'global'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/ordering.signalrhub:${TAG}'
      env: {
        PATH_BASE: '/payment-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.connectionString()
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
        source: 'route(identity-api)'
        disableDefaultEnvVars: true
      }
      ordering: {
        source: 'route(ordering-api)'
        disableDefaultEnvVars: true
      }
      catalog: {
        source: 'route(catalog-api)'
        disableDefaultEnvVars: true
      }
      basket: {
        source: 'route(basket-api)'
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

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: redisKeystoreName
}

resource sqlOrderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: sqlOrderingDbName
}

resource rabbitmq 'Applications.Link/rabbitMQMessageQueues@2022-03-15-privatepreview' existing = if (AZURESERVICEBUSENABLED == 'FALSE') {
  name: rabbitmqName
}
