import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('What container orchestrator to use')
@allowed([
  'K8S'
])
param ORCHESTRATOR_TYPE string

@description('Container image tag to use for eshop images')
param TAG string

@description('Name of the Gateway')
param gatewayName string

@description('Basket Http Route name')
param basketHttpName string

@description('Basket gRPC Route name')
param basketGrpcName string

@description('Ordering Http Route name')
param orderingHttpName string

@description('Ordering gRPC Route name')
param orderingGrpcName string

@description('Identity Http Route name')
param identityHttpName string

@description('Catalog Http Route name')
param catalogHttpName string

@description('Catalog gRPC Route name')
param catalogGrpcName string

@description('Payment Http Route name')
param paymentHttpName string

@description('Web shopping API GW HTTP Route name')
param webshoppingapigwHttpName string

@description('Web shopping API GW HTTP Route 2 name')
param webshoppingapigwHttp2Name string

@description('Web Shopping Aggregator Http Route name')
param webshoppingaggHttpName string

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webshoppingagg
resource webshoppingagg 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshoppingagg'
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
        urls__basket: basketHttp.properties.url
        urls__catalog: catalogHttp.properties.url
        urls__orders: orderingHttp.properties.url
        urls__identity: identityHttp.properties.url
        urls__grpcBasket: basketGrpc.properties.url
        urls__grpcCatalog: catalogGrpc.properties.url
        urls__grpcOrdering: orderingGrpc.properties.url
        CatalogUrlHC: '${catalogHttp.properties.url}/hc'
        OrderingUrlHC: '${orderingHttp.properties.url}/hc'
        IdentityUrlHC: '${identityHttp.properties.url}/hc'
        BasketUrlHC: '${basketHttp.properties.url}/hc'
        PaymentUrlHC: '${paymentHttp.properties.url}/hc'
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webshoppingaggHttp.id
        }
      }
    }
    connections: {
      identity: {
        source: identityHttp.id
        disableDefaultEnvVars: true
      }
      ordering: {
        source: orderingHttp.id
        disableDefaultEnvVars: true
      }
      catalog: {
        source: catalogHttp.id
        disableDefaultEnvVars: true
      }
      basket: {
        source: basketHttp.id
        disableDefaultEnvVars: true
      }
    }
  }
}


// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/apigwws
resource webshoppingapigw 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/eshop-envoy:0.1.4'
      ports: {
        http: {
          containerPort: 80
          provides: webshoppingapigwHttp.id
        }
        http2: {
          containerPort: 8001
          provides: webshoppingapigwHttp2.id
        }
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource basketGrpc 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: basketGrpcName
}

resource catalogGrpc 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: catalogGrpcName
}

resource orderingGrpc 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: orderingGrpcName
}

resource catalogHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: catalogHttpName
}

resource basketHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: basketHttpName
}

resource orderingHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: orderingHttpName
}

resource identityHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityHttpName
}

resource paymentHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: paymentHttpName
}

resource webshoppingaggHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webshoppingaggHttpName
}

resource webshoppingapigwHttp 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webshoppingapigwHttpName
}

resource webshoppingapigwHttp2 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webshoppingapigwHttp2Name
}
