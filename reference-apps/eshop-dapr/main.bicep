import radius as radius

param environment string

param location string = resourceGroup().location
param uniqueSeed string = resourceGroup().id

param sqlAdministratorLogin string  = 'server_admin'
@secure()
param sqlAdministratorLoginPassword string

resource eShopOnDapr 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'eshopondapr'
  properties: {
    environment: environment
  }
}

////////////////////////////////////////////////////////////////////////////////
// Infrastructure
////////////////////////////////////////////////////////////////////////////////

// Azure SQL Database
module sqlServer 'infra/sql-server.bicep' = {
  name: '${deployment().name}-sql'
  params: {
    appId: eShopOnDapr.id
    environment: environment
    location: location
    uniqueSeed: uniqueSeed
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    catalogDbName: 'Microsoft.eShopOnDapr.Services.CatalogDb'
    identityDbName: 'Microsoft.eShopOnDapr.Services.IdentityDb'
    orderingDbName: 'Microsoft.eShopOnDapr.Services.OrderingDb'
  }
}

// Dapr Pub/Sub Broker
module daprPubSub 'infra/dapr-pub-sub.bicep' = {
  name: '${deployment().name}-dapr-pubsub'
  params: {
    appId: eShopOnDapr.id
    environment: environment
    location: location
    uniqueSeed: uniqueSeed
  }
}

// Dapr State Store
module stateStore 'infra/dapr-state-store.bicep' = {
  name: '${deployment().name}-dapr-state-store'
  params: {
    appId: eShopOnDapr.id
    environment: environment
    location: location
    uniqueSeed: uniqueSeed
  }
}

// HTTP Routes
module httpRoutes 'infra/http-routes.bicep' = {
  name: '${deployment().name}-http-routes'
  params: {
    appId: eShopOnDapr.id
  }
}

// Gateway
module gateway 'infra/gateway.bicep' = {
  name: '${deployment().name}-gateway'
  params: {
    appId: eShopOnDapr.id
    blazorClientRouteName: httpRoutes.outputs.blazorClientRouteName
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    seqRouteName: seq.outputs.seqRouteName
    webshoppingGwRouteName: httpRoutes.outputs.webshoppingGwRouteName
    webstatusRouteName: httpRoutes.outputs.webstatusRouteName
  }
}

module seq 'infra/seq.bicep' = {
  name: '${deployment().name}-seq'
  params: {
    appId: eShopOnDapr.id
  }
}

////////////////////////////////////////////////////////////////////////////////
// Services
////////////////////////////////////////////////////////////////////////////////

module blazorClient 'services/blazor-client.bicep' = {
  name: '${deployment().name}-blazor-client'
  params: {
    appId: eShopOnDapr.id
    endpointUrl: gateway.outputs.url
    blazorClientRouteName: httpRoutes.outputs.blazorClientRouteName
    seqRouteName: seq.outputs.seqRouteName
  }
}

module basketApi 'services/basket-api.bicep' = {
  name: '${deployment().name}-basket-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment
    endpointUrl: gateway.outputs.url
    basketApiRouteName: httpRoutes.outputs.basketApiRouteName
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    daprStateStoreName: stateStore.outputs.daprStateStoreName
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    seqRouteName: seq.outputs.seqRouteName
  }
}

module catalogApi 'services/catalog-api.bicep' = {
  name: '${deployment().name}-catalog-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment
    catalogApiRouteName: httpRoutes.outputs.catalogApiRouteName
    catalogDbLinkName: sqlServer.outputs.catalogDbLinkName
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    seqRouteName: seq.outputs.seqRouteName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
  }
}

module identityApi 'services/identity-api.bicep' = {
  name: '${deployment().name}-identity-api'
  params: {
    appId: eShopOnDapr.id
    endpointUrl: gateway.outputs.url
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    identityDbLinkName: sqlServer.outputs.identityDbLinkName
    seqRouteName: seq.outputs.seqRouteName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
  }
}

module orderingApi 'services/ordering-api.bicep' = {
  name: '${deployment().name}-ordering-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment
    endpointUrl: gateway.outputs.url
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    orderingApiRouteName: httpRoutes.outputs.orderingApiRouteName
    orderingDbLinkName: sqlServer.outputs.orderingDbLinkName
    seqRouteName: seq.outputs.seqRouteName
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
  }
}

module paymentApi 'services/payment-api.bicep' = {
  name: '${deployment().name}-payment-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    paymentApiRouteName: httpRoutes.outputs.paymentApiRouteName
    seqRouteName: seq.outputs.seqRouteName
  }
}

module webshoppingAgg 'services/webshopping-agg.bicep' = {
  name: '${deployment().name}-ws-agg'
  params: {
    appId: eShopOnDapr.id
    environment: environment
    endpointUrl: gateway.outputs.url
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    seqRouteName: seq.outputs.seqRouteName
    webshoppingAggRouteName: httpRoutes.outputs.webshoppingAggRouteName
  }
}

module webshoppingGw 'services/webshopping-gw.bicep' = {
  name: '${deployment().name}-ws-gw'
  params: {
    appId: eShopOnDapr.id
    catalogApiRouteName: httpRoutes.outputs.catalogApiRouteName
    catalogApiDaprRouteName: catalogApi.outputs.catalogApiDaprRouteName
    orderingApiRouteName: httpRoutes.outputs.orderingApiRouteName
    orderingApiDaprRouteName: orderingApi.outputs.orderingApiDaprRouteName
    webshoppingGwRouteName: httpRoutes.outputs.webshoppingGwRouteName
  }
}

module webstatus 'services/webstatus.bicep' = {
  name: '${deployment().name}-webstatus'
  params: {
    appId: eShopOnDapr.id
    blazorClientApiRouteName: httpRoutes.outputs.blazorClientRouteName
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    webstatusRouteName: httpRoutes.outputs.webstatusRouteName
  }
}
