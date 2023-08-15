import radius as rad

// Parameters -------------------------------------------------------

@description('Name of the eshop application. Defaults to "eshop"')
param appName string = 'eshop'

@description('Radius environment ID. Set automatically by Radius')
param environment string

@description('SQL administrator username')
param adminLogin string = 'SA'

@description('SQL administrator password')
@secure()
param adminPassword string = newGuid()

@description('Container orchestrator to use. Defaults to "K8S"')
@allowed([
  'K8S'
])
param ORCHESTRATOR_TYPE string = 'K8S'

@description('Optional App Insights Key')
param APPLICATION_INSIGHTS_KEY string = ''

@description('Use Azure storage for custom resource images. Defaults to "False"')
@allowed([
  'True'
  'False'
])
param AZURESTORAGEENABLED string = 'False'

@description('Use Azure Service Bus for messaging. Defaults to "False"')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string = 'False'

@description('Use dev spaces. Defaults to "False"')
@allowed([
  'True'
  'False'
])
param ENABLEDEVSPACES string = 'False'

@description('Container image tag to use for eshop images. Defaults to "linux-dotnet7"')
param TAG string = 'linux-dotnet7'

// Application --------------------------------------------------------

resource eshop 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: appName
  properties: {
    environment: environment
  }
}

// Infrastructure ------------------------------------------------------

module infra 'infra/infra.bicep' = {
  name: 'infra'
  params: {
    application: eshop.id
    environment: environment
    adminLogin: adminLogin
    adminPassword: adminPassword
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
  }
}

// Networking ----------------------------------------------------------

module networking 'infra/networking.bicep' = {
  name: 'networking'
  params: {
    application: eshop.id
  }
}

// Services ------------------------------------------------------------

module basket 'services/basket.bicep' = {
  name: 'basket'
  params: {
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    basketHttpName: networking.outputs.basketHttp
    basketGrpcName: networking.outputs.basketGrpc
    redisBasketName: infra.outputs.redisBasket
    TAG: TAG
    eventBusConnectionString: infra.outputs.eventBusConnectionString
  }
}

module catalog 'services/catalog.bicep' = {
  name: 'catalog'
  params: {
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY 
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
    AZURESTORAGEENABLED: AZURESTORAGEENABLED
    catalogGrpcName: networking.outputs.catalogGrpc
    catalogHttpName: networking.outputs.catalogHttp
    gatewayName: networking.outputs.gateway
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    sqlCatalogDbName: infra.outputs.sqlCatalogDb
    TAG: TAG
    eventBusConnectionString: infra.outputs.eventBusConnectionString
  }
}

module identity 'services/identity.bicep' = {
  name: 'identity'
  params: {
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY
    basketHttpName: networking.outputs.basketHttp
    ENABLEDEVSPACES: ENABLEDEVSPACES
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    orderingHttpName: networking.outputs.orderingHttp
    redisKeystoreName: infra.outputs.redisKeystore
    sqlIdentityDbName: infra.outputs.sqlIdentityDb
    TAG: TAG
    webhooksclientHttpName: networking.outputs.webhooksclientHttp
    webhooksHttpName: networking.outputs.webhooksHttp
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
  }
}

module ordering 'services/ordering.bicep' = {
  name: 'ordering'
  params: {
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY 
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
    basketHttpName: networking.outputs.basketHttp
    catalogHttpName: networking.outputs.catalogHttp
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    orderbgtasksHttpName: networking.outputs.orderbgtasksHttp
    orderingGrpcName: networking.outputs.orderingGrpc
    orderingHttpName: networking.outputs.orderingHttp
    orderingsignalrhubHttpName: networking.outputs.orderingsignalrhubHttp
    redisKeystoreName: infra.outputs.redisKeystore
    sqlOrderingDbName: infra.outputs.sqlOrderingDb
    TAG: TAG
    eventBusConnectionString: infra.outputs.eventBusConnectionString
  }
}

module payment 'services/payment.bicep' = {
  name: 'payment'
  params: {
    application: eshop.id 
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    paymentHttpName: networking.outputs.paymentHttp
    TAG: TAG
    eventBusConnectionString: infra.outputs.eventBusConnectionString
  }
}

module seq 'services/seq.bicep' = {
  name: 'seq'
  params: {
    application: eshop.id 
    seqHttpName: networking.outputs.seqHttp
  }
}

module web 'services/web.bicep' = {
  name: 'web'
  params: {
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    orderingsignalrhubHttpName: networking.outputs.orderingsignalrhubHttp
    redisKeystoreName: infra.outputs.redisKeystore
    TAG: TAG
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webshoppingapigwHttpName: networking.outputs.webshoppingapigwHttp
    webspaHttpName: networking.outputs.webspaHttp
  }
}

module webhooks 'services/webhooks.bicep' = {
  name: 'webhooks'
  params: {
    application: eshop.id
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED 
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    sqlWebhooksDbName: infra.outputs.sqlWebhooksDb
    TAG: TAG
    webhooksclientHttpName: networking.outputs.webhooksclientHttp
    webhooksHttpName: networking.outputs.webhooksHttp
    eventBusConnectionString: infra.outputs.eventBusConnectionString
  }
}

module webshopping 'services/webshopping.bicep' = {
  name: 'webshopping'
  params: {
    application: eshop.id
    basketGrpcName: networking.outputs.basketGrpc
    basketHttpName: networking.outputs.basketHttp
    catalogGrpcName: networking.outputs.catalogGrpc
    catalogHttpName: networking.outputs.catalogHttp
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    orderingGrpcName: networking.outputs.orderingGrpc
    orderingHttpName: networking.outputs.basketHttp
    paymentHttpName: networking.outputs.paymentHttp
    TAG: TAG
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webshoppingapigwHttp2Name: networking.outputs.webshoppingapigwHttp2
    webshoppingapigwHttpName: networking.outputs.webshoppingapigwHttp
  }
}

module webstatus 'services/webstatus.bicep' = {
  name: 'webstatus'
  params: {
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY 
    basketHttpName: networking.outputs.basketHttp
    catalogHttpName: networking.outputs.catalogHttp
    identityHttpName: networking.outputs.identityHttp
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    orderbgtasksHttpName: networking.outputs.orderbgtasksHttp
    orderingHttpName: networking.outputs.orderingHttp
    orderingsignalrhubHttpName: networking.outputs.orderingsignalrhubHttp
    paymentHttpName: networking.outputs.paymentHttp
    TAG: TAG
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webspaHttpName: networking.outputs.webspaHttp
    webstatusHttpName: networking.outputs.webstatusHttp
  }
}
