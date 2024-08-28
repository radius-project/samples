extension radius

@description('The Radius application ID.')
param appId string

@description('The Dapr application ID.')
var daprAppId = 'webstatus'

//-----------------------------------------------------------------------------
// Deploy webstatus container
//-----------------------------------------------------------------------------

resource webstatus 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webstatus'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/webstatus:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        PATH_BASE: {
          value: '/health'
        }
        HealthChecksUI__HealthChecks__0__Name: {
          value: 'Blazor UI Host'
        }
        HealthChecksUI__HealthChecks__0__Uri: {
          value: 'http://blazor-client:80/liveness'
        }
        HealthChecksUI__HealthChecks__1__Name: {
          value: 'Identity API'
        }
        HealthChecksUI__HealthChecks__1__Uri: {
          value: 'http://localhost:3500/v1.0/invoke/identity-api/method/liveness'
        }
        HealthChecksUI__HealthChecks__2__Name: {
          value: 'Basket API'
        }
        HealthChecksUI__HealthChecks__2__Uri: {
          value: 'http://localhost:3500/v1.0/invoke/basket-api/method/liveness'
        }
        HealthChecksUI__HealthChecks__3__Name: {
          value: 'Catalog API'
        }
        HealthChecksUI__HealthChecks__3__Uri: {
          value: 'http://localhost:3500/v1.0/invoke/catalog-api/method/liveness'
        }
        HealthChecksUI__HealthChecks__4__Name: {
          value: 'Ordering API'
        }
        HealthChecksUI__HealthChecks__4__Uri: {
          value: 'http://localhost:3500/v1.0/invoke/ordering-api/method/liveness'
        }
        HealthChecksUI__HealthChecks__5__Name: {
          value: 'Payment API'
        }
        HealthChecksUI__HealthChecks__5__Uri: {
          value: 'http://localhost:3500/v1.0/invoke/payment-api/method/liveness'
        }
        HealthChecksUI__HealthChecks__6__Name: {
          value: 'Web Shopping Aggregator'
        }
        HealthChecksUI__HealthChecks__6__Uri: {
          value: 'http://localhost:3500/v1.0/invoke/webshoppingagg/method/liveness'
        }
      }
      ports: {
        http: {
          containerPort: 80
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: daprAppId
        appPort: 80
      }
    ]
    connections: {
      blazorClient: {
        source: 'http://blazor-client'
      }
    }
  }
}
