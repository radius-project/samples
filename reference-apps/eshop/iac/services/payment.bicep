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

@description('The name of the RabbitMQ Link')
param rabbitmqName string

@description('The connection string of the Azure Service Bus')
@secure()
param serviceBusConnectionString string

// CONTAINERS ---------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/payment-api
resource payment 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'payment-api'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/payment.api:${TAG}'
      env: {
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        'Serilog__MinimumLevel__Override__payment-api.IntegrationEvents.EventHandling': 'Verbose'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        OrchestratorType: ORCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.connectionString()
      }
      ports: {
        http: {
          containerPort: 80
          port: 5108
        }
      }
    }
  }
}

// LINKS -----------------------------------------------------------

resource rabbitmq 'Applications.Link/rabbitMQMessageQueues@2022-03-15-privatepreview' existing = if (AZURESERVICEBUSENABLED == 'FALSE') {
  name: rabbitmqName
}
