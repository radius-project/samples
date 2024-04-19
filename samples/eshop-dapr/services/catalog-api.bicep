import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Catalog database portable resource.')
param catalogDbName string

@description('The name of the Dapr pub/sub component.')
param daprPubSubBrokerName string

@secure() // Decorated with @secure() to circumvent the false positive warning to use secure parameters
@description('The name of the Dapr secret store component.')
param daprSecretStoreName string

@description('The name of the Key Vault to get secrets from.')
param keyVaultName string


@description('The Dapr application ID.')
var daprAppId = 'catalog-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource catalogDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' existing = {
  name: catalogDbName
}

resource daprPubSubBroker 'Applications.Dapr/pubSubBrokers@2023-10-01-preview' existing = {
  name: daprPubSubBrokerName
}

resource daprSecretStore 'Applications.Dapr/secretStores@2023-10-01-preview' existing = {
  name: daprSecretStoreName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

//-----------------------------------------------------------------------------
// Deploy Catalog API container
//-----------------------------------------------------------------------------

resource catalogApi 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'catalog-api'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/catalog.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        RetryMigrations: 'true'
        SeqServerUrl: 'http://seq:5340'
      }
      ports: {
        http: {
          containerPort: 80
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: daprAppId
        appPort: 80
      }
    ]
    connections: {
      catalogDb: {
        source: catalogDb.id
      }
      daprPubSubBroker: {
        source: daprPubSubBroker.id
      }
      daprSecretStore: {
        source: daprSecretStore.id
      }
      // Temporary workaround to grant required role to workload identity.
      keyVault: {
        source: keyVault.id
        iam: {
          kind: 'azure'
          roles: [
            'Key Vault Secrets User'
          ]
        }
      }
      seqRoute: {
        source: 'http://seq:5340'
      }
    }
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = daprAppId
