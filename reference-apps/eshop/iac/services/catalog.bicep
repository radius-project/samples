import radius as rad

// Parameters ---------------------------------------------------------

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

@description('Use Azure storage for custom resource images')
@allowed([
  'True'
  'False'
])
param AZURESTORAGEENABLED string

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

@description('The name of the RabbitMQ Link')
param rabbitmqName string

@description('The name of the Catalog SQL Link')
param sqlCatalogDbName string

@description('The connection string of the Azure Service Bus')
@secure()
param serviceBusConnectionString string

// VARIABLES -----------------------------------------------------------------------------------
var PICBASEURL = '${gateway.properties.url}/webshoppingapigw/c/api/v1/catalog/items/[0]/pic'

// CONTAINERS -------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/catalog-api
resource catalog 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'catalog-api'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/catalog.api:${TAG}'
      env: {
        UseCustomizationData: 'False'
        PATH_BASE: '/catalog-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        OrchestratorType: ORCHESTRATOR_TYPE
        PORT: '80'
        GRPC_PORT: '81'
        PicBaseUrl: PICBASEURL
        AzureStorageEnabled: AZURESTORAGEENABLED
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: 'Server=tcp:${sqlCatalogDb.properties.server},1433;Initial Catalog=${sqlCatalogDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.connectionString()
      }
      ports: {
        http: {
          containerPort: 80
          port: 5101
        }
        grpc: {
          containerPort: 81
          port: 9101
          scheme: 'grpc'
        }
      }
    }
    connections: {
      sql: {
        source: sqlCatalogDb.id
      }
    }
  }
}

// NETWORKING ------------------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

// LINKS -----------------------------------------------------------

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: sqlCatalogDbName
}

resource rabbitmq 'Applications.Link/rabbitMQMessageQueues@2022-03-15-privatepreview' existing = if (AZURESERVICEBUSENABLED == 'FALSE') {
  name: rabbitmqName
}
