import radius as radius

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
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/health'
        HealthChecksUI__HealthChecks__0__Name: 'Blazor UI Host'
        HealthChecksUI__HealthChecks__0__Uri: 'http://blazor-client:80/hc'
        HealthChecksUI__HealthChecks__1__Name: 'Identity API'
        HealthChecksUI__HealthChecks__1__Uri: 'http://localhost:3500/v1.0/invoke/identity-api/method/hc'
        HealthChecksUI__HealthChecks__2__Name: 'Basket API'
        HealthChecksUI__HealthChecks__2__Uri: 'http://localhost:3500/v1.0/invoke/basket-api/method/hc'
        HealthChecksUI__HealthChecks__3__Name: 'Catalog API'
        HealthChecksUI__HealthChecks__3__Uri: 'http://localhost:3500/v1.0/invoke/catalog-api/method/hc'
        HealthChecksUI__HealthChecks__4__Name: 'Ordering API'
        HealthChecksUI__HealthChecks__4__Uri: 'http://localhost:3500/v1.0/invoke/ordering-api/method/hc'
        HealthChecksUI__HealthChecks__5__Name: 'Payment API'
        HealthChecksUI__HealthChecks__5__Uri: 'http://localhost:3500/v1.0/invoke/payment-api/method/hc'
        HealthChecksUI__HealthChecks__6__Name: 'Web Shopping Aggregator'
        HealthChecksUI__HealthChecks__6__Uri: 'http://localhost:3500/v1.0/invoke/webshoppingagg/method/hc'
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
