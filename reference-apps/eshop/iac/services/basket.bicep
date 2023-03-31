import radius as rad

// Parameters ---------------------------------------------------------

@description('Radius region to deploy resources into. Only global is supported today')
@allowed([
  'global'
])
param ucpLocation string

@description('Radius application ID')
param application string

@description('Cotnainer image tag to use for eshop images')
param TAG string

@description('Optional App Insights Key')
param APPLICATION_INSIGHTS_KEY string

@description('Use Azure Service Bus for messaging.')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

@description('What container orchestrator to use')
@allowed([
  'K8S'
])
param ORCHESTRATOR_TYPE string

@description('The name of the Radius Gateway')
param gatewayName string

@description('The name of the Redis Basket Link')
param redisBasketName string

@description('The name of the RabbitMQ Link')
param rabbitmqName string

@description('The connection string of the Azure Service Bus')
@secure()
param serviceBusConnectionString string

// Container -------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/basket-api
resource basket 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'basket-api'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/basket.api:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        PATH_BASE: '/basket-api'
        OrchestratorType: ORCHESTRATOR_TYPE
        PORT: '80'
        GRPC_PORT: '81'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: '${redisBasket.properties.host}:${redisBasket.properties.port},password=${redisBasket.password()},abortConnect=False'
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.connectionString()
        identityUrl: 'http://identity-api:5105'
        IdentityUrlExternal: '${gateway.properties.url}/identity-api'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5103
        }
        grpc: {
          containerPort: 81
          port: 9103
        }
      }
    }
    connections: {
      redis: {
        source: redisBasket.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'route(identity-api)'
        disableDefaultEnvVars: true
      }
    }
  }
}

// Networking -------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

// Links ------------------------------------------

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: redisBasketName
}

resource rabbitmq 'Applications.Link/rabbitMQMessageQueues@2022-03-15-privatepreview' existing = if (AZURESERVICEBUSENABLED == 'FALSE') {
  name: rabbitmqName
}
