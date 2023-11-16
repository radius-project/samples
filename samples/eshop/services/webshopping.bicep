import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container registry to pull from, with optional path.')
param imageRegistry string

@description('Container image tag to use for eshop images')
param imageTag string

@description('Name of the Gateway')
param gatewayName string

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webshoppingagg
resource webshoppingagg 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webshoppingagg'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/webshoppingagg:${imageTag}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        PATH_BASE: '/webshoppingagg'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ORCHESTRATOR_TYPE: 'K8S'
        IsClusterEnv: 'True'
        urls__basket: 'http://basket-api:5103'
        urls__catalog: 'http://catalog-api:5101'
        urls__orders: 'http://ordering-api:5102'
        urls__identity: 'http://identity-api:5105'
        urls__grpcBasket: 'grpc://basket-api:9103'
        urls__grpcCatalog: 'grpc://catalog-api:9101'
        urls__grpcOrdering: 'grpc://ordering-api:9102'
        CatalogUrlHC: 'http://catalog-api:5101/hc'
        OrderingUrlHC: 'http://ordering-api:5102/hc'
        IdentityUrlHC: 'http://identity-api:5105/hc'
        BasketUrlHC: 'http://basket-api:5103/hc'
        PaymentUrlHC: 'http://payment-api:5108/hc'
        IdentityUrlExternal: '${gateway.properties.url}/identity-api'
      }
      ports: {
        http: {
          containerPort: 80
          port: 5121
        }
      }
      livenessProbe:{
        kind:'httpGet'
        path:'/hc'
        containerPort:80
      }
    }
    connections: {
      identity: {
        source: 'http://identity-api:5105'
        disableDefaultEnvVars: true
      }
      ordering: {
        source: 'http://ordering-api:5102'
        disableDefaultEnvVars: true
      }
      catalog: {
        source: 'http://catalog-api:5101'
        disableDefaultEnvVars: true
      }
      basket: {
        source: 'http://basket-api:5103'
        disableDefaultEnvVars: true
      }
    }
  }
}


// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/apigwws
resource webshoppingapigw 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webshoppingapigw'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/eshop-envoy:0.1.0'
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
      livenessProbe:{
        kind:'httpGet'
        path:'/hc'
        containerPort:80
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}
