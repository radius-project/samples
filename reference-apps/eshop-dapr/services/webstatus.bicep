import radius as radius

param appId string

param blazorClientApiRouteName string
param identityApiRouteName string
param webstatusRouteName string

var daprAppId = 'webstatus'

resource blazorClientApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: blazorClientApiRouteName
}

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource webstatusRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: webstatusRouteName
}

resource webstatus 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webstatus'
  location: 'global'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/webstatus:latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/health'
        HealthChecksUI__HealthChecks__0__Name: 'Blazor UI Host'
        HealthChecksUI__HealthChecks__0__Uri: '${blazorClientApiRoute.properties.url}/hc'
        HealthChecksUI__HealthChecks__1__Name: 'Identity API'
        HealthChecksUI__HealthChecks__1__Uri: '${identityApiRoute.properties.url}/hc'
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
          provides: webstatusRoute.id
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
        source: blazorClientApiRoute.id
      }
      identityApi: {
        source: identityApiRoute.id
      }
    }
  }
}
