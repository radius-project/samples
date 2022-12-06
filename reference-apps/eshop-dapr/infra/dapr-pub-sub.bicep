import radius as radius

param appId string
param environment string
param location string
param uniqueSeed string

resource serviceBus 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: 'sb-${uniqueString(uniqueSeed)}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

resource daprPubSubBroker 'Applications.Link/daprPubSubBrokers@2022-03-15-privatepreview' = {
  name: 'pubsub'
  location: 'global'
  properties: {
    application: appId
    environment: environment
    mode: 'resource'
    resource: serviceBus.id
  }
}

output daprPubSubBrokerName string = daprPubSubBroker.name
