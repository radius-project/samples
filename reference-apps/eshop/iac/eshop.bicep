import radius as rad

// Paramaters -------------------------------------------------------

@description('Radius region to deploy resources into. Only global is supported today')
param ucpLocation string = 'global'

@description('Name of the eshop application. Defaults to "eshop"')
param appName string = 'eshop'

@description('Radius environment ID. Set automatically by Radius')
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

@description('Use Azure Service Bus for messaging. Defaults to False')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string = 'False'

@description('Use dev spaces. Defaults to False')
@allowed([
  'True'
  'False'
])
param ENABLEDEVSPACES string = 'False'

@description('Cotnainer image tag to use for eshop images. Defaults to linux-dotnet7')
param TAG string = 'linux-dotnet7'

@description('Azure Service Bus authorization rule ID')
param azureAuthRuleId string = 'eshopsb${uniqueString(resourceGroup().id)}/eshop_event_bus/Root'

@description('Name of your EKS cluster. Only used if deploying with AWS infrastructure.')
param eksClusterName string = ''

// Application --------------------------------------------------------

resource eshop 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: appName
  location: ucpLocation
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
    ucpLocation: ucpLocation
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
    ucpLocation: ucpLocation
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

// Networking ----------------------------------------------------------

module networking 'services/networking.bicep' = {
  name: 'networking'
  params: {
    ucpLocation: ucpLocation
    application: eshop.id
  }
}

// Services ------------------------------------------------------------

module basket 'services/basket.bicep' = {
  name: 'basket'
  params: {
    ucpLocation: ucpLocation
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    basketHttpName: networking.outputs.basketHttp
    basketGrpcName: networking.outputs.basketGrpc
    rabbitmqName: rabbitmq.name
    redisBasketName: redisBasket.name
    TAG: TAG
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? listKeys(azureAuthRuleId, '2022-01-01-preview').primaryConnectionString : ''
  }
}

module catalog 'services/catalog.bicep' = {
  name: 'catalog'
  params: {
    ucpLocation: ucpLocation
    adminLogin: adminLogin
    adminPassword: adminPassword
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY 
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED
    AZURESTORAGEENABLED: AZURESTORAGEENABLED
    catalogGrpcName: networking.outputs.catalogGrpc
    catalogHttpName: networking.outputs.catalogHttp
    gatewayName: networking.outputs.gateway
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    rabbitmqName: rabbitmq.name
    sqlCatalogDbName: sqlCatalogDb.name
    TAG: TAG
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? listKeys(azureAuthRuleId, '2022-01-01-preview').primaryConnectionString : ''
  }
}

module identity 'services/identity.bicep' = {
  name: 'identity'
  params: {
    adminLogin: adminLogin
    adminPassword: adminPassword
    application: eshop.id
    APPLICATION_INSIGHTS_KEY: APPLICATION_INSIGHTS_KEY
    basketHttpName: networking.outputs.basketHttp
    ENABLEDEVSPACES: ENABLEDEVSPACES
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    orderingHttpName: networking.outputs.orderingHttp
    redisKeystoreName: redisKeystore.name
    sqlIdentityDbName: sqlIdentityDb.name
    TAG: TAG
    ucpLocation: ucpLocation 
    webhooksclientHttpName: networking.outputs.webhooksclientHttp
    webhooksHttpName: networking.outputs.webhooksHttp
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
  }
}

module ordering 'services/ordering.bicep' = {
  name: 'ordering'
  params: {
    adminLogin: adminLogin
    adminPassword: adminPassword
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
    rabbitmqName: rabbitmq.name
    redisKeystoreName: redisKeystore.name
    sqlOrderingDbName: sqlOrderingDb.name
    TAG: TAG
    ucpLocation: ucpLocation
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? listKeys(azureAuthRuleId, '2022-01-01-preview').primaryConnectionString : ''
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
    rabbitmqName: rabbitmq.name
    TAG: TAG
    ucpLocation: ucpLocation 
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? listKeys(azureAuthRuleId, '2022-01-01-preview').primaryConnectionString : ''
  }
}

module seq 'services/seq.bicep' = {
  name: 'seq'
  params: {
    application: eshop.id 
    seqHttpName: networking.outputs.seqHttp
    ucpLocation: ucpLocation
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
    redisKeystoreName: redisKeystore.id
    TAG: TAG
    ucpLocation: ucpLocation
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webshoppingapigwHttpName: networking.outputs.webshoppingapigwHttp
    webspaHttpName: networking.outputs.webspaHttp
  }
}

module webhooks 'services/webhooks.bicep' = {
  name: 'webhooks'
  params: {
    adminLogin: adminLogin
    adminPassword: adminPassword
    application: eshop.id
    AZURESERVICEBUSENABLED: AZURESERVICEBUSENABLED 
    gatewayName: networking.outputs.gateway
    identityHttpName: networking.outputs.identityHttp
    ORCHESTRATOR_TYPE: ORCHESTRATOR_TYPE
    rabbitmqName: rabbitmq.name
    sqlWebhooksDbName: sqlWebhooksDb.name
    TAG: TAG
    ucpLocation: ucpLocation 
    webhooksclientHttpName: networking.outputs.webhooksclientHttp
    webhooksHttpName: networking.outputs.webhooksHttp
    serviceBusConnectionString: (AZURESERVICEBUSENABLED == 'True') ? listKeys(azureAuthRuleId, '2022-01-01-preview').primaryConnectionString : ''
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
    rabbitmqName: rabbitmq.id
    TAG: TAG
    ucpLocation: ucpLocation 
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webshoppingapigwHttp2Name: networking.outputs.webshoppingapigwHttp2
    webshoppingapigwHttpName: networking.outputs.webshoppingapigwHttp
  }
}

module webstatus 'services/webstatus.bicep' = {
  name: 'websatatus'
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
    ucpLocation: ucpLocation 
    webmvcHttpName: networking.outputs.webmvcHttp
    webshoppingaggHttpName: networking.outputs.webshoppingaggHttp
    webspaHttpName: networking.outputs.webspaHttp
    webstatusHttpName: networking.outputs.webstatusHttp
  }
}

// Links -----------------------------------------------------------
// TODO: Switch to Recipes once ready

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: 'identitydb'
}

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: 'catalogdb'
}

resource sqlOrderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: 'orderingdb'
}

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: 'webhooksdb'
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: 'keystore-data'
}

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' existing = {
  name: 'basket-data'
}

resource rabbitmq 'Applications.Link/rabbitmqMessageQueues@2022-03-15-privatepreview' existing = {
  name: 'eshop-event-bus'
}
