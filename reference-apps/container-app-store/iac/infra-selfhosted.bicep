param location string = resourceGroup().location

resource account 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: 'containerappstore${uniqueString(resourceGroup().id)}'
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

output tableId string = account::tableServices::table.id 
