import radius as radius

param location string

param name string = 'todoapp-cosmos-${uniqueString(resourceGroup().id)}'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: toLower(name)
  location: location
  kind: 'MongoDB'
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
  }
  
  resource cosmosDb 'mongodbDatabases' = {
    name: 'db'
    properties: {
      resource: {
        id: 'db'
      }
      options: {
        throughput: 400
      }
    }
  }

}

output dbName string = cosmosAccount::cosmosDb.id
