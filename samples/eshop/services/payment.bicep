import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container image tag to use for eshop images')
param TAG string

@description('Name of the Payment HTTP route')
param paymentHttpName string

@description('The connection string for the event bus')
@secure()
param eventBusConnectionString string

@description('Use Azure Service Bus for messaging. Allowed values: "True", "False".')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

// CONTAINERS ---------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/payment-api
resource payment 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'payment-api'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/payment.api:${TAG}'
      env: {
        'Serilog__MinimumLevel__Override__payment-api.IntegrationEvents.EventHandling': 'Verbose'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        ORCHESTRATOR_TYPE: 'K8S'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: eventBusConnectionString
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
