import radius as radius

param location string = resourceGroup().location

param applicationId string

param environmentId string

param accountGuid string = newGuid()

resource account 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: uniqueString(accountGuid)
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'

  resource tableServices 'tableServices' = {
    name: 'default'

    resource table 'tables' = {
      name: 'dapr'
    }
  }
}

resource statestore 'Applications.Connector/daprStateStores@2022-03-15-privatepreview' = {
  name: 'orders'
  location: 'global'
  properties: {
    kind:  'state.azure.tablestorage'
    application: applicationId
    environment: environmentId
    resource: account::tableServices::table.id 
  }
}

output statestoreID string = statestore.id
