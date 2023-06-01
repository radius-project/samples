import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the basket API Dapr route.')
param basketApiDaprRouteName string

@description('The name of the Blazor Client API HTTP route.')
param blazorClientApiRouteName string

@description('The name of the Catalog API Dapr route.')
param catalogApiDaprRouteName string

@description('The name of the Identity API Dapr route.')
param identityApiDaprRouteName string

@description('The name of the Catalog API Dapr route.')
param orderingApiDaprRouteName string

@description('The name of the Ordering API Dapr route.')
param paymentApiDaprRouteName string

@description('The name of the Web Shopping Aggregator API Dapr route.')
param webshoppingAggDaprRouteName string

@description('The name of the webstatus API HTTP route.')
param webstatusRouteName string

@description('The Dapr application ID.')
var daprAppId = 'webstatus'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource basketApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: basketApiDaprRouteName
}

resource blazorClientApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: blazorClientApiRouteName
}

resource catalogApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: catalogApiDaprRouteName
}

resource identityApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiDaprRouteName
}

resource orderingApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: orderingApiDaprRouteName
}

resource paymentApiDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: paymentApiDaprRouteName
}

resource webshoppingAggDaprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' existing = {
  name: webshoppingAggDaprRouteName
}

resource webstatusRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: webstatusRouteName
}

//-----------------------------------------------------------------------------
// Deploy webstatus container
//-----------------------------------------------------------------------------

resource webstatus 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webstatus'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/webstatus:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/health'
        HealthChecksUI__HealthChecks__0__Name: 'Blazor UI Host'
        HealthChecksUI__HealthChecks__0__Uri: '${blazorClientApiRoute.properties.url}/hc'
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
      basketApiDaprRoute: {
        source: basketApiDaprRoute.id
      }
      catalogApiDaprRoute: {
        source: catalogApiDaprRoute.id
      }
      identityApiDaprRoute: {
        source: identityApiDaprRoute.id
      }
      orderingApiDaprRoute: {
        source: orderingApiDaprRoute.id
      }
      paymentApiDaprRoute: {
        source: paymentApiDaprRoute.id
      }
      webshoppingAggDaprRoute: {
        source: webshoppingAggDaprRoute.id
      }
    }
  }
}
