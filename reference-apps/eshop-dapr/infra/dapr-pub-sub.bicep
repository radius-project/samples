import radius as radius

@description('The Radius application ID.')
param appId string

@description('The Radius environment name.')
param environment string

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The unique seed used to generate resource names.')
param uniqueSeed string = resourceGroup().id

//-----------------------------------------------------------------------------
// Create the Service Bus
//-----------------------------------------------------------------------------

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: 'sb-${uniqueString(uniqueSeed)}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }

  resource authorizationRule 'AuthorizationRules' = {
    name: 'eshopondaprpubsub'
    properties: {
      rights: [
        'Listen'
        'Send'
        'Manage'
      ]
    }
  }
}

//-----------------------------------------------------------------------------
// Create the Dapr pub sub component
//-----------------------------------------------------------------------------

resource daprPubSubBroker 'Applications.Link/daprPubSubBrokers@2022-03-15-privatepreview' = {
  name: 'eshopondapr-pubsub'
  location: 'global'
  properties: {
    application: appId
    environment: environment
    resourceProvisioning: 'manual'
    resources: [
      {
        id: serviceBus.id
      }
    ]
    type: 'pubsub.azure.servicebus.topics'
    version: 'v1'
    metadata: {
      connectionString: serviceBus::authorizationRule.listKeys().primaryConnectionString
    }
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output daprPubSubBrokerName string = daprPubSubBroker.name
