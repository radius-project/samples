import radius as rad

// Parameters ---------------------------------------------------------

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

@description('Container image tag to use for eshop images')
param TAG string

@description('Name of the Gateway')
param gatewayName string

@description('The name of the Catalog HTTP Route')
param catalogHttpName string

@description('The name of the Catalog gRPC Route')
param catalogGrpcName string

@description('The name of the Catalog SQL Link')
param sqlCatalogDbName string

@description('The connection string for the event bus')
@secure()
param eventBusConnectionString string

// VARIABLES -----------------------------------------------------------------------------------

var PICBASEURL = '${gateway.properties.url}/webshoppingapigw/c/api/v1/catalog/items/[0]/pic'

// CONTAINERS -------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/catalog-api
resource catalog 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'catalog-api'
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
        ConnectionString: sqlCatalogDb.connectionString()
        EventBusConnection: eventBusConnectionString
      }
      ports: {
        http: {
          containerPort: 80
          provides: catalogHttp.id
        }
        grpc: {
          containerPort: 81
          provides: catalogGrpc.id
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

resource catalogHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: catalogHttpName
}

resource catalogGrpc 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: catalogGrpcName
}

// LINKS -----------------------------------------------------------

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: sqlCatalogDbName
}
