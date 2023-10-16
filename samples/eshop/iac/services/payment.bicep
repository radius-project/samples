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

@description('Name of the Payment HTTP route')
param paymentHttpName string

@description('The name of the RabbitMQ portable resource')
param rabbitmqName string

@description('The connection string of the Azure Service Bus')
@secure()
param serviceBusConnectionString string

// CONTAINERS ---------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/payment-api
resource payment 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'payment-api'
  properties: {
    application: application
    container: {
      image: 'ghcr.io/radius-project/samples/eshop/payment.api:${TAG}'
      env: {
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        'Serilog__MinimumLevel__Override__payment-api.IntegrationEvents.EventHandling': 'Verbose'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        OrchestratorType: ORCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.properties.host
      }
      ports: {
        http: {
          containerPort: 80
          provides: paymentHttp.id
        }
      }
    }
  }
}

// NETWORKING ------------------------------------------------------

resource paymentHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: paymentHttpName
}

// PORTABLE RESOURCES -----------------------------------------------------------

resource rabbitmq 'Applications.Messaging/rabbitMQQueues@2023-10-01-preview' existing = {
  name: rabbitmqName
}
