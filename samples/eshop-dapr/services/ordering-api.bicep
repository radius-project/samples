import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Dapr pub/sub component.')
param daprPubSubBrokerName string

@secure() // Decorated with @secure() to circumvent the false positive warning to use secure parameters
@description('The name of the Dapr secret store component.')
param daprSecretStoreName string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The name of the Key Vault to get secrets from.')
param keyVaultName string

@description('The name of the Ordering database portable resource.')
param orderingDbName string

@description('The Dapr application ID.')
var daprAppId = 'ordering-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource daprPubSubBroker 'Applications.Dapr/pubSubBrokers@2023-10-01-preview' existing = {
  name: daprPubSubBrokerName
}

resource daprSecretStore 'Applications.Dapr/secretStores@2023-10-01-preview' existing = {
  name: daprSecretStoreName
}

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

resource orderingDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' existing = {
  name: orderingDbName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

//-----------------------------------------------------------------------------
// Deploy Ordering API container
//-----------------------------------------------------------------------------

resource orderingApi 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'ordering-api'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/ordering.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        IdentityUrl: 'http://identity-api:80'
        IdentityUrlExternal: '${gateway.properties.url}/identity/'
        RetryMigrations: 'true'
        SeqServerUrl: 'http://seq:5340'
        SendConfirmationEmail: 'false'
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
      daprPubSubBroker: {
        source: daprPubSubBroker.id
      }
      daprSecretStore: {
        source: daprSecretStore.id
      }
      identityApiRoute: {
        source: 'http://identity-api'
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
      orderingDb: {
        source: orderingDb.id
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

