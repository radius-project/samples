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

@description('Cotnainer image tag to use for eshop images')
param TAG string

@description('Name of the Gateway')
param gatewayName string

@description('The name of the RabbitMQ Link')
param rabbitmqName string

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webshoppingagg
resource webshoppingagg 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshoppingagg'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop/webshoppingagg:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        PATH_BASE: '/webshoppingagg'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        urls__basket: 'http://basket-api:5103'
        urls__catalog: 'http://catalog-api:5101'
        urls__orders: 'http://ordering-api:5102'
        urls__identity: 'http://identity-api:5105'
        urls__grpcBasket: 'http://basket-api:9103'
        urls__grpcCatalog: 'http://catalog-api:9101'
        urls__grpcOrdering: 'http://ordering-api:9102'
        CatalogUrlHC: 'http://catalog-api:5101/hc'
        OrderingUrlHC: 'http://ordering-api:5102/hc'
        IdentityUrlHC: 'http://identity-api:5105/hc'
        BasketUrlHC: 'http://basket-api:5103/hc'
        PaymentUrlHC: 'http://payments-api:5108/hc'
        IdentityUrlExternal: '${gateway.properties.url}/identity-api'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5121
        }
      }
    }
    connections: {
      rabbitmq: {
        source: rabbitmq.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'route(identity-api)'
        disableDefaultEnvVars: true
      }
      ordering: {
        source: 'route(ordering-api)'
        disableDefaultEnvVars: true
      }
      catalog: {
        source: 'route(catalog-api)'
        disableDefaultEnvVars: true
      }
      basket: {
        source: 'route(basket-api)'
        disableDefaultEnvVars: true
      }
    }
  }
}


// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/apigwws
resource webshoppingapigw 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw'
  location: 'global'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop-envoy:0.1.4'
      ports: {
        http: {
          containerPort: 80
          port: 5202
        }
        http2: {
          containerPort: 8001
          port: 15202
        }
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}


// LINKS --------------------------------------------------------

resource rabbitmq 'Applications.Link/rabbitMQMessageQueues@2022-03-15-privatepreview' existing = {
  name: rabbitmqName
}
