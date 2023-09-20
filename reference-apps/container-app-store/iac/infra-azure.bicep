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

resource statestore 'Applications.Dapr/stateStores@2023-10-01-preview' = {
  name: 'orders'
  properties: {
    application: applicationId
    environment: environment
    resourceProvisioning: 'manual'
    resources: [
      { id: account.id }
      { id: account::tableServices::table.id }
    ]
    metadata: {
      accountName: account.name
      accountKey: account.listKeys().keys[0].value
      tableName: account::tableServices::table.name
    }
    type: 'state.azure.tablestorage'
    version: 'v1'
  }
}

output statestoreID string = statestore.id
