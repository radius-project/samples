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

resource environment 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'eshopondapr'
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
resource eShopOnDapr 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'eshopondapr'
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

// Gateway
module gateway 'infra/gateway.bicep' = {
  name: '${deployment().name}-gateway'
  params: {
    appId: eShopOnDapr.id
  }
}

//-----------------------------------------------------------------------------
// Services
//-----------------------------------------------------------------------------

module seq 'services/seq.bicep' = {
  name: '${deployment().name}-seq'
  params: {
    appId: eShopOnDapr.id
  }
}

module blazorClient 'services/blazor-client.bicep' = {
  name: '${deployment().name}-blazor-client'
  params: {
    appId: eShopOnDapr.id
    gatewayName: gateway.outputs.gatewayName
  }
}

module basketApi 'services/basket-api.bicep' = {
  name: '${deployment().name}-basket-api'
  params: {
    appId: eShopOnDapr.id
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    daprStateStoreName: stateStore.outputs.daprStateStoreName
    gatewayName: gateway.outputs.gatewayName
  }
}

module catalogApi 'services/catalog-api.bicep' = {
  name: '${deployment().name}-catalog-api'
  params: {
    appId: eShopOnDapr.id
    catalogDbName: sqlServer.outputs.catalogDbName
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    daprSecretStoreName: secretStore.outputs.daprSecretStoreName
    keyVaultName: secretStore.outputs.keyVaultName
  }
}

module identityApi 'services/identity-api.bicep' = {
  name: '${deployment().name}-identity-api'
  params: {
    appId: eShopOnDapr.id
    daprSecretStoreName: secretStore.outputs.daprSecretStoreName
    identityDbName: sqlServer.outputs.identityDbName
    gatewayName: gateway.outputs.gatewayName
    keyVaultName: secretStore.outputs.keyVaultName
  }
}

module orderingApi 'services/ordering-api.bicep' = {
  name: '${deployment().name}-ordering-api'
  params: {
    appId: eShopOnDapr.id
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
    daprSecretStoreName: secretStore.outputs.daprSecretStoreName
    gatewayName: gateway.outputs.gatewayName
    keyVaultName: secretStore.outputs.keyVaultName
    orderingDbName: sqlServer.outputs.orderingDbName
  }
}

module paymentApi 'services/payment-api.bicep' = {
  name: '${deployment().name}-payment-api'
  params: {
    appId: eShopOnDapr.id
    daprPubSubBrokerName: daprPubSub.outputs.daprPubSubBrokerName
  }
}

module webshoppingAgg 'services/webshopping-agg.bicep' = {
  name: '${deployment().name}-ws-agg'
  params: {
    appId: eShopOnDapr.id
    gatewayName: gateway.outputs.gatewayName
  }
}

module webshoppingGw 'services/webshopping-gw.bicep' = {
  name: '${deployment().name}-ws-gw'
  params: {
    appId: eShopOnDapr.id
  }
}

module webstatus 'services/webstatus.bicep' = {
  name: '${deployment().name}-webstatus'
  params: {
    appId: eShopOnDapr.id
  }
}
