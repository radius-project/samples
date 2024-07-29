import radius as rad

// Parameters ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container registry to pull from, with optional path.')
param imageRegistry string

@description('Container image tag to use for eshop images')
param imageTag string

@description('Name of the Gateway')
param gatewayName string

@description('The name of the Catalog SQL portable resource')
param sqlCatalogDbName string

@description('The connection string for the event bus')
@secure()
param eventBusConnectionString string

@description('Use Azure Service Bus for messaging. Allowed values: "True", "False".')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

// VARIABLES -----------------------------------------------------------------------------------

var PICBASEURL = '${gateway.properties.url}/webshoppingapigw/c/api/v1/catalog/items/[0]/pic'

// CONTAINERS -------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/catalog-api
resource catalog 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'catalog-api'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/catalog.api:${imageTag}'
      env: {
        UseCustomizationData: 'False'
        PATH_BASE: '/catalog-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ORCHESTRATOR_TYPE: 'K8S'
        PORT: '80'
        GRPC_PORT: '81'
        PicBaseUrl: PICBASEURL
        AzureStorageEnabled: 'False'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: sqlCatalogDb.connectionString()
        EventBusConnection: eventBusConnectionString
      }
      ports: {
        http: {
          containerPort: 80
          port: 5101
        }
        grpc: {
          containerPort: 81
          port: 9101
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

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

// PORTABLE RESOURCES -----------------------------------------------------------

resource sqlCatalogDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' existing = {
  name: sqlCatalogDbName
}
