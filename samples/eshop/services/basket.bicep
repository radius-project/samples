extension radius

// Parameters ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container registry to pull from, with optional path.')
param imageRegistry string

@description('Container image tag to use for eshop images')
param imageTag string

@description('The name of the Radius Gateway')
param gatewayName string

@description('The name of the Redis Basket portable resource')
param redisBasketName string

@description('The connection string for the event bus')
@secure()
param eventBusConnectionString string

@description('Use Azure Service Bus for messaging. Allowed values: "True", "False".')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

// Container -------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/basket-api
resource basket 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'basket-api'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/basket.api:${imageTag}'
      env: {
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        UseLoadTest: {
          value: 'False'
        }
        PATH_BASE: {
          value: '/basket-api'
        }
        ORCHESTRATOR_TYPE: {
          value: 'K8S'
        }
        PORT: {
          value: '80'
        }
        GRPC_PORT: {
          value: '81'
        }
        AzureServiceBusEnabled: {
          value: AZURESERVICEBUSENABLED
        }
        ConnectionString: {
          value: redisBasket.listSecrets().connectionString
        }
        EventBusConnection: {
          value: eventBusConnectionString
        }
        identityUrl: {
          value: 'http://identity-api:5105'
        }
        IdentityUrlExternal: {
          value: '${gateway.properties.url}/identity-api'
        }
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
      livenessProbe: {
        kind: 'httpGet'
        path: '/liveness'
        containerPort: 80
      }
      readinessProbe: {
        kind: 'httpGet'
        path: '/hc'
        containerPort: 80
      }
    }

    connections: {
      redis: {
        source: redisBasket.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'http://identity-api:5105'
        disableDefaultEnvVars: true
      }
    }

  }
}

// Networking -------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

// Portable Resource ------------------------------------------

resource redisBasket 'Applications.Datastores/redisCaches@2023-10-01-preview' existing = {
  name: redisBasketName
}
