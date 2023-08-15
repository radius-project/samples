import radius as rad

// PARAMETERS ---------------------------------------------------------

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

@description('Container image tag to use for eshop images. Defaults to linux-dotnet7')
param TAG string

@description('Name of the Gateway')
param gatewayName string

@description('Name of the Identity HTTP Route')
param identityHttpName string

@description('Name of the Webhooks HTTP Route')
param webhooksHttpName string

@description('Name of the WebhooksClient HTTP Route')
param webhooksclientHttpName string

@description('The name of the Webhooks SQL Link')
param sqlWebhooksDbName string

@description('The connection string for the event bus')
@secure()
param eventBusConnectionString string

// CONTAINERS -----------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-api
resource webhooks 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webhooks-api'
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
        ConnectionString: sqlWebhooksDb.connectionString()
        EventBusConnection: eventBusConnectionString
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webhooksHttp.id
        }
      }
    }
    connections: {
      sql: {
        source: sqlWebhooksDb.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: identityHttp.id
        disableDefaultEnvVars: true
      }
    }
  }
}


// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-web
resource webhooksclient 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webhooks-client'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/webhooks.client:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Production'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webhooks-web'
        Token: 'WebHooks-Demo-Web'
        CallBackUrl: '${gateway.properties.url}/${webhooksclientHttp.properties.hostname}'
        SelfUrl: webhooksclientHttp.properties.url
        WebhooksUrl: webhooksHttp.properties.url
        IdentityUrl: '${gateway.properties.url}/${identityHttp.properties.hostname}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webhooksclientHttp.id
        }
      }
    }
    connections: {
      webhooks: {
        source: webhooksHttp.id
      }
      identity: {
        source: identityHttp.id
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource identityHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityHttpName
}

resource webhooksHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing =  {
  name: webhooksHttpName
}

resource webhooksclientHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webhooksclientHttpName
}

// LINKS -----------------------------------------------------------

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: sqlWebhooksDbName
}
