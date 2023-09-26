import radius as radius

@description('The Radius application ID.')
param appId string

@secure() // Decorated with @secure() to circumvent the false positive warning to use secure parameters
@description('The name of the Dapr secret store component.')
param daprSecretStoreName string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The name of the Identity database portable resource.')
param identityDbName string

@description('The name of the Key Vault to get secrets from.')
param keyVaultName string

var daprAppId = 'identity-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource daprSecretStore 'Applications.Dapr/secretStores@2023-10-01-preview' existing = {
  name: daprSecretStoreName
}

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

resource identityDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' existing = {
  name: identityDbName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

//-----------------------------------------------------------------------------
// Deploy Identity API container
//-----------------------------------------------------------------------------

resource identityApi 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'identity-api'
  properties: {
    application: appId
    container: {
      image: 'ghcr.io/radius-project/samples/eshopdapr/identity.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/identity/'
        BlazorClientUrlExternal: gateway.properties.url
        IssuerUrl: '${gateway.properties.url}/identity/'
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
      daprSecretStore: {
        source: daprSecretStore.id
      }
      identityDb: {
        source: identityDb.id
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
