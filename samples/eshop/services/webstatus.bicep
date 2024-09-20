extension radius

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
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        HealthChecksUI__HealthChecks__0__Name: {
          value: 'WebMVC HTTP Check'
        }
        HealthChecksUI__HealthChecks__0__Uri: {
          value: 'http://webmvc:5100/liveness'
        }
        HealthChecksUI__HealthChecks__1__Name: {
          value: 'WebSPA HTTP Check'
        }
        HealthChecksUI__HealthChecks__1__Uri: {
          value: 'http://web-spa:5104/liveness'
        }
        HealthChecksUI__HealthChecks__2__Name: {
          value: 'Web Shopping Aggregator GW HTTP Check'
        }
        HealthChecksUI__HealthChecks__2__Uri: {
          value: 'http://webshoppingagg:5121/liveness'
        }
        HealthChecksUI__HealthChecks__4__Name: {
          value: 'Ordering HTTP Check'
        }
        HealthChecksUI__HealthChecks__4__Uri: {
          value: 'http://ordering-api:5102/liveness'
        }
        HealthChecksUI__HealthChecks__5__Name: {
          value: 'Basket HTTP Check'
        }
        HealthChecksUI__HealthChecks__5__Uri: {
          value: 'http://basket-api:5103/liveness'
        }
        HealthChecksUI__HealthChecks__6__Name: {
          value: 'Catalog HTTP Check'
        }
        HealthChecksUI__HealthChecks__6__Uri: {
          value: 'http://catalog-api/liveness'
        }
        HealthChecksUI__HealthChecks__7__Name: {
          value: 'Identity HTTP Check'
        }
        HealthChecksUI__HealthChecks__7__Uri: {
          value: 'http://identity-api:5105/liveness'
        }
        HealthChecksUI__HealthChecks__8__Name: {
          value: 'Payments HTTP Check'
        }
        HealthChecksUI__HealthChecks__8__Uri: {
          value: 'http://payment-api:5108/liveness'
        }
        HealthChecksUI__HealthChecks__9__Name: {
          value: 'Ordering SignalRHub HTTP Check'
        }
        HealthChecksUI__HealthChecks__9__Uri: {
          value: 'http://ordering-signalrhub:5112/liveness'
        }
        HealthChecksUI__HealthChecks__10__Name: {
          value: 'Ordering HTTP Background Check'
        }
        HealthChecksUI__HealthChecks__10__Uri: {
          value: 'http://ordering-backgroundtasks:5111/liveness'
        }
        ORCHESTRATOR_TYPE: {
          value: 'K8S'
        }
      }
      ports: {
        http: {
          containerPort: 80
          port: 8107
        }
      }
      livenessProbe: {
        kind: 'tcp'
        containerPort: 80
      }
    }
  }
}
