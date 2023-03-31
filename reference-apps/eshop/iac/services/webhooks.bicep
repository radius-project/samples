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

@description('Use Azure Service Bus for messaging')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

@description('Cotnainer image tag to use for eshop images. Defaults to linux-dotnet7')
param TAG string

@description('SQL administrator username')
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

@description('Name of the Gateway')
param gatewayName string

@description('The name of the Webhooks SQL Link')
param sqlWebhooksDbName string

@description('The name of the RabbitMQ Link')
param rabbitmqName string

@description('The connection string of the Azure Service Bus')
@secure()
param serviceBusConnectionString string

// CONTAINERS -----------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-api
resource webhooks 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webhooks-api'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/webhooks.api:${TAG}'
      env: {
        PATH_BASE: '/webhooks-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: ORCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: 'Server=tcp:${sqlWebhooksDb.properties.server},1433;Initial Catalog=${sqlWebhooksDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
        EventBusConnection: (AZURESERVICEBUSENABLED == 'True') ? serviceBusConnectionString : rabbitmq.connectionString()
        identityUrl: 'http://identity-api:5105'
        IdentityUrlExternal: '${gateway.properties.url}/identity-api'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5113
        }
      }
    }
    connections: {
      sql: {
        source: sqlWebhooksDb.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'route(identity-api)'
        disableDefaultEnvVars: true
      }
    }
  }
}


// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-web
resource webhooksclient 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webhooks-client'
  location: 'global'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/webhooks.client:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Production'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webhooks-web'
        Token: 'WebHooks-Demo-Web'
        CallBackUrl: '${gateway.properties.url}/webhooks-client'
        SelfUrl: 'http://webhooks-client'
        WebhooksUrl: 'http://webhooks-api'
        IdentityUrl: '${gateway.properties.url}/identity-api'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5114
        }
      }
    }
    connections: {
      webhooks: {
        source: 'route(webhooks-api)'
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'route(identity-api)'
        disableDefaultEnvVars: true
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

// LINKS -----------------------------------------------------------

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: sqlWebhooksDbName
}

resource rabbitmq 'Applications.Link/rabbitMQMessageQueues@2022-03-15-privatepreview' existing = if (AZURESERVICEBUSENABLED == 'FALSE') {
  name: rabbitmqName
}
