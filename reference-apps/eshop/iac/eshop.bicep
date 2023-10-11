import radius as rad

// Paramaters -------------------------------------------------------

@description('Name of the eshop application. Defaults to "eshop"')
param appName string = 'eshop'

@description('Radius Environment ID. Set automatically by Radius')
param environment string

@description('What type of infrastructure to use. Options are "containers", "azure", or "aws". Defaults to containers')
@allowed([
  'containers'
  'azure'
  'aws'
])
param platform string = 'containers'

@description('SQL administrator username')
param adminLogin string = (platform == 'containers') ? 'SA' : 'sqladmin'

@description('SQL administrator password')
@secure()
param adminPassword string = newGuid()

@description('What container orchestrator to use. Defaults to K8S')
@allowed([
  'K8S'
])
param ORCHESTRATOR_TYPE string = 'K8S'

@description('Optional App Insights Key')
param APPLICATION_INSIGHTS_KEY string = ''

@description('Use Azure storage for custom resource images. Defaults to False')
@allowed([
  'True'
  'False'
])
param AZURESTORAGEENABLED string = 'False'

var AZURESERVICEBUSENABLED = (platform == 'azure') ? 'True' : 'False'

@description('Use dev spaces. Defaults to False')
@allowed([
  'True'
  'False'
])
param ENABLEDEVSPACES string = 'False'

@description('Cotnainer image tag to use for eshop images. Defaults to linux-dotnet7')
param TAG string = 'linux-dotnet7'

@description('Name of your EKS cluster. Only used if deploying with AWS infrastructure.')
param eksClusterName string = ''

// Application --------------------------------------------------------

resource eshop 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: appName
  properties: {
    environment: environment
  }
}

// Infrastructure ------------------------------------------------------

module containers 'infra/containers.bicep' = if (platform == 'containers') {
  name: 'containers'
  params: {
    application: eshop.id
    environment: environment
    adminPassword: adminPassword
  }
}

module azure 'infra/azure.bicep' = if (platform == 'azure') {
  name: 'azure'
  // Temporarily disable linter rule until deployment engine returns Azure resource group location instead of UCP resource group location
  #disable-next-line explicit-values-for-loc-params
  params: {
    application: eshop.id
    environment: environment
    adminLogin: adminLogin
    adminPassword: adminPassword
  }
}

module aws 'infra/aws.bicep' = if (platform == 'aws') {
  name: 'aws'
  params: {
    application: eshop.id
    eksClusterName: eksClusterName
    environment: environment
    adminLogin: adminLogin
    adminPassword: adminPassword
  }
}

// Portable Resources -----------------------------------------------------------
// TODO: Switch to Recipes once ready

module links 'infra/links.bicep' = {
  name: 'links'
  dependsOn: [
    containers
    azure
    aws
  ]
}

// Networking ----------------------------------------------------------

module networking 'services/networking.bicep' = {
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
    rabbitmqName: links.outputs.rabbitmq
    redisBasketName: links.outputs.redisBasket
    TAG: TAG
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? azure.outputs.serviceBusAuthConnectionString : ''
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
    rabbitmqName: links.outputs.rabbitmq
    sqlCatalogDbName: links.outputs.sqlCatalogDb
    TAG: TAG
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? azure.outputs.serviceBusAuthConnectionString : ''
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
    redisKeystoreName: links.outputs.redisKeystore
    sqlIdentityDbName: links.outputs.sqlIdentityDb
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
    rabbitmqName: links.outputs.rabbitmq
    redisKeystoreName: links.outputs.redisKeystore
    sqlOrderingDbName: links.outputs.sqlOrderingDb
    TAG: TAG
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? azure.outputs.serviceBusAuthConnectionString : ''
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
    rabbitmqName: links.outputs.rabbitmq
    TAG: TAG
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? azure.outputs.serviceBusAuthConnectionString : ''
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
    redisKeystoreName: links.outputs.redisKeystore
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
    rabbitmqName: links.outputs.rabbitmq
    sqlWebhooksDbName: links.outputs.sqlWebhooksDb
    TAG: TAG
    webhooksclientHttpName: networking.outputs.webhooksclientHttp
    webhooksHttpName: networking.outputs.webhooksHttp
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? azure.outputs.serviceBusAuthConnectionString : ''
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
    rabbitmqName: links.outputs.rabbitmq
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
