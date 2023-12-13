import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container registry to pull from, with optional path.')
param imageRegistry string

@description('Container image tag to use for eshop images')
param imageTag string

@description('Basket Http Route name')
param basketHttpName string

@description('Ordering Http Route name')
param orderingHttpName string

@description('Ordering SignalR Hub Http Route name')
param orderingsignalrhubHttpName string

@description('Ordering Background Tasks Http Route name')
param orderbgtasksHttpName string

@description('Identity Http Route name')
param identityHttpName string

@description('Catalog Http Route name')
param catalogHttpName string

@description('Payment Http Route name')
param paymentHttpName string

@description('Web MVC Http Route name')
param webmvcHttpName string

@description('Web SPA Http Route name')
param webspaHttpName string

@description('Web Shopping Aggregator Http Route name')
param webshoppingaggHttpName string

@description('Web Status Http Route name')
param webstatusHttpName string

// CONTAINAERS ---------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webstatus
resource webstatus 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webstatus'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/webstatus:${imageTag}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        HealthChecksUI__HealthChecks__0__Name: 'WebMVC HTTP Check'
        HealthChecksUI__HealthChecks__0__Uri: '${webmvcHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__1__Name: 'WebSPA HTTP Check'
        HealthChecksUI__HealthChecks__1__Uri: '${webspaHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__2__Name: 'Web Shopping Aggregator GW HTTP Check'
        HealthChecksUI__HealthChecks__2__Uri: '${webshoppingaggHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__4__Name: 'Ordering HTTP Check'
        HealthChecksUI__HealthChecks__4__Uri: '${orderingHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__5__Name: 'Basket HTTP Check'
        HealthChecksUI__HealthChecks__5__Uri: '${basketHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__6__Name: 'Catalog HTTP Check'
        HealthChecksUI__HealthChecks__6__Uri: '${catalogHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__7__Name: 'Identity HTTP Check'
        HealthChecksUI__HealthChecks__7__Uri: '${identityHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__8__Name: 'Payments HTTP Check'
        HealthChecksUI__HealthChecks__8__Uri: '${paymentHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__9__Name: 'Ordering SignalRHub HTTP Check'
        HealthChecksUI__HealthChecks__9__Uri: '${orderingsignalrhubHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__10__Name: 'Ordering HTTP Background Check'
        HealthChecksUI__HealthChecks__10__Uri: '${orderbgtasksHttp.properties.url}/hc'
        ORCHESTRATOR_TYPE: 'K8S'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webstatusHttp.id
        }
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource catalogHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: catalogHttpName
}

resource basketHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: basketHttpName
}

resource orderingHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: orderingHttpName
}

resource orderingsignalrhubHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: orderingsignalrhubHttpName
}

resource orderbgtasksHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: orderbgtasksHttpName
}

resource identityHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: identityHttpName
}

resource paymentHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: paymentHttpName
}

resource webmvcHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: webmvcHttpName
}

resource webspaHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: webspaHttpName
}

resource webshoppingaggHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: webshoppingaggHttpName
}

resource webstatusHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: webstatusHttpName
}
