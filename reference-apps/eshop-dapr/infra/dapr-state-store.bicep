import radius as radius

param appId string
param environment string
param location string
param uniqueSeed string

param cosmosAccountName string = 'cosmos-${uniqueString(uniqueSeed)}'
param cosmosDbName string = 'eShop'
param cosmosDbCollectionName string = 'state'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource cosmosDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-04-15' = {
  parent: cosmosAccount
  name: cosmosDbName
  properties: {
    resource: {
      id: cosmosDbName
    }
  }
}

resource cosmosCollection 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-04-15' = {
  parent: cosmosDb
  name: cosmosDbCollectionName
  properties: {
    resource: {
      id: cosmosDbCollectionName
      partitionKey: {
        paths: [
          '/partitionKey'
        ]
        kind: 'Hash'
      }
    }
  }
}

resource daprStateStore 'Applications.Link/daprStateStores@2022-03-15-privatepreview' = {
  name: 'statestore'
  location: 'global'
  dependsOn: [
    cosmosCollection
  ]
  properties: {
    application: appId
    environment: environment
    kind: 'generic'
    type: 'state.azure.cosmosdb'
    version: 'v1'
    metadata: {
      url: cosmosAccount.properties.documentEndpoint
      masterKey: listKeys(cosmosAccount.id, cosmosAccount.apiVersion).primaryMasterKey
      database: cosmosDbName
      collection: cosmosDbCollectionName
      actorStateStore: 'true'
    }
  }
}

output daprStateStoreName string = daprStateStore.name
