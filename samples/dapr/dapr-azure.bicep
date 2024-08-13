extension radius

param location string = resourceGroup().location
param environment string

resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: 'dapr'
  properties: {
    environment: environment
  }
}

resource backend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'backend'
  properties: {
    application: app.id
    container: {
      image: 'ghcr.io/radius-project/samples/dapr-backend:latest'
      ports: {
        web: {
          containerPort: 3000
        }
      }
    }
    connections: {
      orders: {
        source: stateStore.id
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'backend'
        appPort: 3000
      }
    ]
  }
}

resource frontend 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'frontend'
  properties: {
    application: app.id
    container: {
      image: 'ghcr.io/radius-project/samples/dapr-frontend:latest'
      env: {
        CONNECTION_BACKEND_APPID: backend.name
        ASPNETCORE_URLS: 'http://*:8080'
      }
      ports: {
        ui: {
          containerPort: 8080
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'frontend'
      }
    ]
  }
}

resource account 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: 'dapr${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }

  resource tableServices 'tableServices' = {
    name: 'default'

    resource table 'tables' = {
      name: 'dapr'
    }
  }
}

resource stateStore 'Applications.Dapr/stateStores@2023-10-01-preview' = {
  name: 'orders'
  properties: {
    environment: environment
    application: app.id
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
