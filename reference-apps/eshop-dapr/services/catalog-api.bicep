import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Catalog API HTTP route.')
param catalogApiRouteName string

@description('The name of the Catalog database portable resource.')
param catalogDbName string

@description('The name of the Dapr pub/sub component.')
param daprPubSubBrokerName string

@secure() // Decorated with @secure() to circumvent the false positive warning to use secure parameters
@description('The name of the Dapr secret store component.')
param daprSecretStoreName string

@description('The name of the Key Vault to get secrets from.')
param keyVaultName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

@description('The Dapr application ID.')
var daprAppId = 'catalog-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource catalogApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: catalogApiRouteName
}

resource catalogDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: catalogDbName
}

resource daprPubSubBroker 'Applications.Dapr/pubSubBrokers@2022-03-15-privatepreview' existing = {
  name: daprPubSubBrokerName
}

resource daprSecretStore 'Applications.Dapr/secretStores@2022-03-15-privatepreview' existing = {
  name: daprSecretStoreName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Catalog API container
//-----------------------------------------------------------------------------

resource catalogApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'catalog-api'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/catalog.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        RetryMigrations: 'true'
        SeqServerUrl: seqRoute.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: catalogApiRoute.id
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
        source: seqRoute.id
      }
    }
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = daprAppId
