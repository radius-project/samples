import radius as rad

// Parameters -------------------------------------------------------

@description('Radius environment ID. Set automatically by Radius')
param environment string

@description('Container image tag to use for eshop images. Defaults to "linux-dotnet7".')
param TAG string = 'linux-dotnet7'

// Variables ---------------------------------------------------------

var applicationName = 'eshop'

// Get the environment name from the environment ID
var environmentName = last(split(environment, '/'))
resource eshopEnvironment 'Applications.Core/environments@2023-10-01-preview' existing = {
  name: environmentName
}

// Check if the environment has the rabbitmqqueues recipe enabled
// If it does not, use Azure ServiceBus
var AZURESERVICEBUSENABLED = contains(eshopEnvironment.properties.recipes, 'Applications.Messaging/rabbitmqqueues') ? 'False' : 'True'

// Application --------------------------------------------------------

resource eshopApplication 'Applications.Core/applications@2023-10-01-preview' = {
  name: applicationName
  properties: {
    environment: environment
  }
}

// Infrastructure ------------------------------------------------------

module infra 'infra/infra.bicep' = {
  name: 'infra'
  params: {
    application: eshopApplication.id
    environment: environment
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
  }
}

// Networking ----------------------------------------------------------

module networking 'infra/networking.bicep' = {
  name: 'networking'
  params: {
    application: eshopApplication.id
  }
}

// Services ------------------------------------------------------------

module basket 'services/basket.bicep' = {
  name: 'basket'
  params: {
    application: eshopApplication.id
    TAG: TAG
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    basketHttpName: networking.outputs.basketHttp
    basketGrpcName: networking.outputs.basketGrpc
    redisBasketName: infra.outputs.redisBasket
    eventBusConnectionString: infra.outputs.eventBusConnectionString
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
  }
}

module catalog 'services/catalog.bicep' = {
  name: 'catalog'
  params: {
    application: eshopApplication.id
    TAG: TAG
    catalogGrpcName: networking.outputs.catalogGrpc
    catalogHttpName: networking.outputs.catalogHttp
    gatewayName: networking.outputs.gateway
    sqlCatalogDbName: infra.outputs.sqlCatalogDb
    eventBusConnectionString: infra.outputs.eventBusConnectionString
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
  }
}

module identity 'services/identity.bicep' = {
  name: 'identity'
  params: {
    application: eshopApplication.id
    TAG: TAG
    basketHttpName: networking.outputs.basketHttp
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    orderingHttpName: networking.outputs.orderingHttp
    redisKeystoreName: infra.outputs.redisKeystore
    sqlIdentityDbName: infra.outputs.sqlIdentityDb
    webhooksclientHttpName: networking.outputs.webhooksclientHttp
    webhooksHttpName: networking.outputs.webhooksHttp
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
  }
}

module ordering 'services/ordering.bicep' = {
  name: 'ordering'
  params: {
    application: eshopApplication.id
    TAG: TAG
    basketHttpName: networking.outputs.basketHttp
    catalogHttpName: networking.outputs.catalogHttp
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    orderbgtasksHttpName: networking.outputs.orderbgtasksHttp
    orderingGrpcName: networking.outputs.orderingGrpc
    orderingHttpName: networking.outputs.orderingHttp
    orderingsignalrhubHttpName: networking.outputs.orderingsignalrhubHttp
    redisKeystoreName: infra.outputs.redisKeystore
    sqlOrderingDbName: infra.outputs.sqlOrderingDb
    eventBusConnectionString: infra.outputs.eventBusConnectionString
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
  }
}

module payment 'services/payment.bicep' = {
  name: 'payment'
  params: {
    application: eshopApplication.id
    TAG: TAG
    paymentHttpName: networking.outputs.paymentHttp
    eventBusConnectionString: infra.outputs.eventBusConnectionString
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
  }
}

module seq 'services/seq.bicep' = {
  name: 'seq'
  params: {
    application: eshopApplication.id 
    seqHttpName: networking.outputs.seqHttp
  }
}

module web 'services/web.bicep' = {
  name: 'web'
  params: {
    application: eshopApplication.id
    TAG: TAG
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    orderingsignalrhubHttpName: networking.outputs.orderingsignalrhubHttp
    redisKeystoreName: infra.outputs.redisKeystore
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webshoppingapigwHttpName: networking.outputs.webshoppingapigwHttp
    webspaHttpName: networking.outputs.webspaHttp
  }
}

module webhooks 'services/webhooks.bicep' = {
  name: 'webhooks'
  params: {
    application: eshopApplication.id
    TAG: TAG
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    sqlWebhooksDbName: infra.outputs.sqlWebhooksDb
    webhooksclientHttpName: networking.outputs.webhooksclientHttp
    webhooksHttpName: networking.outputs.webhooksHttp
    eventBusConnectionString: infra.outputs.eventBusConnectionString
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
  }
}

module webshopping 'services/webshopping.bicep' = {
  name: 'webshopping'
  params: {
    application: eshopApplication.id
    TAG: TAG
    basketGrpcName: networking.outputs.basketGrpc
    basketHttpName: networking.outputs.basketHttp
    catalogGrpcName: networking.outputs.catalogGrpc
    catalogHttpName: networking.outputs.catalogHttp
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    orderingGrpcName: networking.outputs.orderingGrpc
    orderingHttpName: networking.outputs.basketHttp
    paymentHttpName: networking.outputs.paymentHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webshoppingapigwHttp2Name: networking.outputs.webshoppingapigwHttp2
    webshoppingapigwHttpName: networking.outputs.webshoppingapigwHttp
  }
}

module webstatus 'services/webstatus.bicep' = {
  name: 'webstatus'
  params: {
    application: eshopApplication.id
    TAG: TAG
    basketHttpName: networking.outputs.basketHttp
    catalogHttpName: networking.outputs.catalogHttp
    identityHttpName: networking.outputs.identityHttp
    orderbgtasksHttpName: networking.outputs.orderbgtasksHttp
    orderingHttpName: networking.outputs.orderingHttp
    orderingsignalrhubHttpName: networking.outputs.orderingsignalrhubHttp
    paymentHttpName: networking.outputs.paymentHttp
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webspaHttpName: networking.outputs.webspaHttp
    webstatusHttpName: networking.outputs.webstatusHttp
  }
}
