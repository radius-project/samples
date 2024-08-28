extension radius

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
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        PATH_BASE: {
          value: '/webshoppingagg'
        }
        ASPNETCORE_URLS:  {
          value: 'http://0.0.0.0:80'
        }
        ORCHESTRATOR_TYPE: {
          value: 'K8S'
        }
        IsClusterEnv: {
          value: 'True'
        }
        urls__basket: {
          value: 'http://basket-api:5103'
        }
        urls__catalog: {
          value: 'http://catalog-api:5101'
        }
        urls__orders: {
          value: 'http://ordering-api:5102'
        }
        urls__identity: {
          value: 'http://identity-api:5105'
        }
        urls__grpcBasket: {
          value: 'grpc://basket-api:9103'
        }
        urls__grpcCatalog: {
          value: 'grpc://catalog-api:9101'
        }
        urls__grpcOrdering: {
          value: 'grpc://ordering-api:9102'
        }
        CatalogUrlHC: {
          value: 'http://catalog-api:5101/liveness'
        }
        OrderingUrlHC: {
          value: 'http://ordering-api:5102/liveness'
        }
        IdentityUrlHC: {
          value: 'http://identity-api:5105/liveness'
        }
        BasketUrlHC: {
          value: 'http://basket-api:5103/liveness'
        }
        PaymentUrlHC: {
          value: 'http://payment-api:5108/liveness'
        }
        IdentityUrlExternal: {
          value: '${gateway.properties.url}/identity-api'
        }
      }
      ports: {
        http: {
          containerPort: 80
          port: 5121
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
      livenessProbe: {
        kind: 'tcp'
        containerPort: 80
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}
