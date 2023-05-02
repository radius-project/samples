import radius as radius

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The unique seed used to generate resource names.')
param uniqueSeed string = resourceGroup().id

@description('The SQL administrator login name. This is used to create the SQL Server.')
param sqlAdministratorLogin string  = 'server_admin'
@description('The SQL administrator login password. This is used to create the SQL Server.')
@secure()
#disable-next-line secure-parameter-default
param sqlAdministratorLoginPassword string = 'P@ssw0rd1'

@description('Specifies the oidc issuer URL for Workload Identity.')
param oidcIssuer string

resource environment 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'eshopondapr'
  location: 'global'
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: 'eshopondapr-env'
      identity: {
        kind: 'azure.com.workload'
        oidcIssuer: oidcIssuer
      }
    }
    providers: {
      azure: {
        scope: resourceGroup().id
      }
    }
  }
}

// The Radius application definition.
resource eShopOnDapr 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'eshopondapr'
  location: 'global'
  properties: {
    environment: environment.id
    extensions: [
      {
          kind: 'kubernetesNamespace'
          namespace: 'eshopondapr-app'
      }
    ]
  }
}

//-----------------------------------------------------------------------------
// Infrastructure
//-----------------------------------------------------------------------------

// Azure SQL Database
module sqlServer 'infra/sql-server.bicep' = {
  name: '${deployment().name}-sql'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    location: location
    uniqueSeed: uniqueSeed
    sqlAdministratorLogin: sqlAdministratorLogin
    sqlAdministratorLoginPassword: sqlAdministratorLoginPassword
    keyVaultName: secretStore.outputs.keyVaultName
  }
}

// Dapr Secret Store
module secretStore 'infra/dapr-secret-store.bicep' = {
  name: '${deployment().name}-dapr-secret-store'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    location: location
    uniqueSeed: uniqueSeed
  }
}

// Dapr Pub/Sub Broker
module daprPubSub 'infra/dapr-pub-sub.bicep' = {
  name: '${deployment().name}-dapr-pubsub'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    location: location
    uniqueSeed: uniqueSeed
  }
}

// Dapr State Store
module stateStore 'infra/dapr-state-store.bicep' = {
  name: '${deployment().name}-dapr-state-store'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
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
    seqRouteName: httpRoutes.outputs.seqRouteName
    webshoppingGwRouteName: httpRoutes.outputs.webshoppingGwRouteName
    webstatusRouteName: httpRoutes.outputs.webstatusRouteName
  }
}

//-----------------------------------------------------------------------------
// Services
//-----------------------------------------------------------------------------

module seq 'services/seq.bicep' = {
  name: '${deployment().name}-seq'
  params: {
    appId: eShopOnDapr.id
    seqRouteName: httpRoutes.outputs.seqRouteName
  }
}

module blazorClient 'services/blazor-client.bicep' = {
  name: '${deployment().name}-blazor-client'
  params: {
    appId: eShopOnDapr.id
    blazorClientRouteName: httpRoutes.outputs.blazorClientRouteName
    gatewayName: gateway.outputs.gatewayName
    seqRouteName: httpRoutes.outputs.seqRouteName
  }
}

module basketApi 'services/basket-api.bicep' = {
  name: '${deployment().name}-basket-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    basketApiRouteName: httpRoutes.outputs.basketApiRouteName
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    daprStateStoreName: stateStore.outputs.daprStateStoreName
    gatewayName: gateway.outputs.gatewayName
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    seqRouteName: httpRoutes.outputs.seqRouteName
  }
}

module catalogApi 'services/catalog-api.bicep' = {
  name: '${deployment().name}-catalog-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    catalogApiRouteName: httpRoutes.outputs.catalogApiRouteName
    catalogDbName: sqlServer.outputs.catalogDbName
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    daprSecretStoreName: secretStore.outputs.daprSecretStoreName
    keyVaultName: secretStore.outputs.keyVaultName
    seqRouteName: httpRoutes.outputs.seqRouteName
  }
}

module identityApi 'services/identity-api.bicep' = {
  name: '${deployment().name}-identity-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    daprSecretStoreName: secretStore.outputs.daprSecretStoreName
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    identityDbName: sqlServer.outputs.identityDbName
    gatewayName: gateway.outputs.gatewayName
    keyVaultName: secretStore.outputs.keyVaultName
    seqRouteName: httpRoutes.outputs.seqRouteName
  }
}

module orderingApi 'services/ordering-api.bicep' = {
  name: '${deployment().name}-ordering-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    daprSecretStoreName: secretStore.outputs.daprSecretStoreName
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    gatewayName: gateway.outputs.gatewayName
    keyVaultName: secretStore.outputs.keyVaultName
    orderingApiRouteName: httpRoutes.outputs.orderingApiRouteName
    orderingDbName: sqlServer.outputs.orderingDbName
    seqRouteName: httpRoutes.outputs.seqRouteName
  }
}

module paymentApi 'services/payment-api.bicep' = {
  name: '${deployment().name}-payment-api'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    paymentApiRouteName: httpRoutes.outputs.paymentApiRouteName
    seqRouteName: httpRoutes.outputs.seqRouteName
  }
}

module webshoppingAgg 'services/webshopping-agg.bicep' = {
  name: '${deployment().name}-ws-agg'
  params: {
    appId: eShopOnDapr.id
    environment: environment.id
    basketApiDaprRouteName: basketApi.outputs.daprRouteName
    catalogApiDaprRouteName: catalogApi.outputs.daprRouteName
    identityApiRouteName: httpRoutes.outputs.identityApiRouteName
    identityApiDaprRouteName: identityApi.outputs.daprRouteName
    gatewayName: gateway.outputs.gatewayName
    seqRouteName: httpRoutes.outputs.seqRouteName
    webshoppingAggRouteName: httpRoutes.outputs.webshoppingAggRouteName
  }
}

module webshoppingGw 'services/webshopping-gw.bicep' = {
  name: '${deployment().name}-ws-gw'
  params: {
    appId: eShopOnDapr.id
    catalogApiRouteName: httpRoutes.outputs.catalogApiRouteName
    catalogApiDaprRouteName: catalogApi.outputs.daprRouteName
    orderingApiRouteName: httpRoutes.outputs.orderingApiRouteName
    orderingApiDaprRouteName: orderingApi.outputs.daprRouteName
    webshoppingGwRouteName: httpRoutes.outputs.webshoppingGwRouteName
  }
}

module webstatus 'services/webstatus.bicep' = {
  name: '${deployment().name}-webstatus'
  params: {
    appId: eShopOnDapr.id
    basketApiDaprRouteName: basketApi.outputs.daprRouteName
    blazorClientApiRouteName: httpRoutes.outputs.blazorClientRouteName
    catalogApiDaprRouteName: catalogApi.outputs.daprRouteName
    identityApiDaprRouteName: identityApi.outputs.daprRouteName
    orderingApiDaprRouteName: orderingApi.outputs.daprRouteName
    paymentApiDaprRouteName: paymentApi.outputs.daprRouteName
    webshoppingAggDaprRouteName: webshoppingAgg.outputs.daprRouteName
    webstatusRouteName: httpRoutes.outputs.webstatusRouteName
  }
}
