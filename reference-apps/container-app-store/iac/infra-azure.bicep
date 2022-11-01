import radius as radius

param location string = resourceGroup().location

param applicationId string

param environment string

resource account 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: 'store${uniqueString(resourceGroup().id)}'
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

resource statestore 'Applications.Link/daprStateStores@2022-03-15-privatepreview' = {
  name: 'orders'
  location: 'global'
  properties: {
    kind:  'state.azure.tablestorage'
    application: applicationId
    environment: environment
    resource: account::tableServices::table.id 
  }
}

output statestoreID string = statestore.id
