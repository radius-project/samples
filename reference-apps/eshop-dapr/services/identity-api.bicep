import radius as radius

@description('The Radius application ID.')
param appId string

@secure() // Decorated with @secure() to circumvent the false positive warning to use secure parameters
@description('The name of the Dapr secret store component.')
param daprSecretStoreName string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The name of the Identity API HTTP route.')
param identityApiRouteName string

@description('The name of the Identity database portable resource.')
param identityDbName string

@description('The name of the Key Vault to get secrets from.')
param keyVaultName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

var daprAppId = 'identity-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource daprSecretStore 'Applications.Dapr/secretStores@2022-03-15-privatepreview' existing = {
  name: daprSecretStoreName
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource identityApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource identityDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: identityDbName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Identity API container
//-----------------------------------------------------------------------------

resource identityApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'identity-api'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/identity.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/identity/'
        BlazorClientUrlExternal: gateway.properties.url
        IssuerUrl: '${gateway.properties.url}/identity/'
        RetryMigrations: 'true'
        SeqServerUrl: seqRoute.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: identityApiRoute.id
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
        source: seqRoute.id
      }
    }
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output appId string = daprAppId
