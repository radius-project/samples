extension radius

@description('The Radius application ID.')
param appId string

@description('The Radius environment name.')
param environment string

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The unique seed used to generate resource names.')
param uniqueSeed string = resourceGroup().id

@description('The Cosmos DB account name.')
param cosmosAccountName string = 'cosmos-${uniqueString(uniqueSeed)}'

@description('The Cosmos DB database name.')
param cosmosDbName string = 'eShop'

@description('The Cosmos DB collection name.')
param cosmosDbCollectionName string = 'state'

//-----------------------------------------------------------------------------
// Create the Cosmos account, database and collection
//-----------------------------------------------------------------------------

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

//-----------------------------------------------------------------------------
// Create the Dapr state store component
//-----------------------------------------------------------------------------

resource daprStateStore 'Applications.Dapr/stateStores@2023-10-01-preview' = {
  name: 'eshopondapr-statestore'
  location: 'global'
  dependsOn: [
    cosmosCollection
  ]
  properties: {
    application: appId
    environment: environment
    resourceProvisioning: 'manual'
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

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output daprStateStoreName string = daprStateStore.name
