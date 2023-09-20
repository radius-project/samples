import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container registry to pull from, with optional path.')
param imageRegistry string

@description('Container image tag to use for eshop images')
param imageTag string


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
        HealthChecksUI__HealthChecks__0__Uri: 'http://webmvc:5100/hc'
        HealthChecksUI__HealthChecks__1__Name: 'WebSPA HTTP Check'
        HealthChecksUI__HealthChecks__1__Uri: 'http://web-spa:5104/hc'
        HealthChecksUI__HealthChecks__2__Name: 'Web Shopping Aggregator GW HTTP Check'
        HealthChecksUI__HealthChecks__2__Uri: 'http://webshoppingagg:5121/hc'
        HealthChecksUI__HealthChecks__4__Name: 'Ordering HTTP Check'
        HealthChecksUI__HealthChecks__4__Uri: 'http://ordering-api:5102/hc'
        HealthChecksUI__HealthChecks__5__Name: 'Basket HTTP Check'
        HealthChecksUI__HealthChecks__5__Uri: 'http://basket-api:5103/hc'
        HealthChecksUI__HealthChecks__6__Name: 'Catalog HTTP Check'
        HealthChecksUI__HealthChecks__6__Uri: 'http://catalog-api/hc'
        HealthChecksUI__HealthChecks__7__Name: 'Identity HTTP Check'
        HealthChecksUI__HealthChecks__7__Uri: 'http://identity-api:5105/hc'
        HealthChecksUI__HealthChecks__8__Name: 'Payments HTTP Check'
        HealthChecksUI__HealthChecks__8__Uri: 'http://payment-api:5108/hc'
        HealthChecksUI__HealthChecks__9__Name: 'Ordering SignalRHub HTTP Check'
        HealthChecksUI__HealthChecks__9__Uri: 'http://ordering-signalrhub:5112/hc'
        HealthChecksUI__HealthChecks__10__Name: 'Ordering HTTP Background Check'
        HealthChecksUI__HealthChecks__10__Uri: 'http://ordering-backgroundtasks:5111/hc'
        ORCHESTRATOR_TYPE: 'K8S'
      }
      ports: {
        http: {
          containerPort: 80
          port: 8107
        }
      }
    }
  }
}
