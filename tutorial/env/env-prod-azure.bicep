import radius as radius

@description('resource id of the radius environment')
param environment string

@description('azure location for resources')
param location string = resourceGroup().location

@description('name of the database. used for radius connector')
param dbname string = 'tododb'

@description('name of the cosmosdb account')
param cosmosAccountName string = '${dbname}-${uniqueString(resourceGroup().id)}'

resource db 'Applications.Connector/mongoDatabases@2022-03-15-privatepreview' = {
  name: dbname
  location: 'global'
  properties: {
    environment: environment
    resource: cosmosAccount::cosmosDb.id
  }
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-04-15' = {
  name: toLower(cosmosAccountName)
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
