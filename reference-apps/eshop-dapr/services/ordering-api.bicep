import radius as radius

@description('The Radius application ID.')
param appId string

@description('The Radius environment name.')
param environment string

@description('The name of the Dapr pub/sub component.')
param daprPubSubBrokerName string

@secure() // Decorated with @secure() to circumvent the false positive warning to use secure parameters
@description('The name of the Dapr secret store component.')
param daprSecretStoreName string

@description('The name of the Radius gateway.')
param gatewayName string

@description('The name of the Identity API HTTP route.')
param identityApiRouteName string

@description('The name of the Key Vault to get secrets from.')
param keyVaultName string

@description('The name of the Ordering API HTTP route.')
param orderingApiRouteName string

@description('The name of the Ordering database link.')
param orderingDbName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

@description('The Dapr application ID.')
var daprAppId = 'ordering-api'

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource daprPubSubBroker 'Applications.Link/daprPubSubBrokers@2022-03-15-privatepreview' existing = {
  name: daprPubSubBrokerName
}

resource daprSecretStore 'Applications.Link/daprSecretStores@2022-03-15-privatepreview' existing = {
  name: daprSecretStoreName
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' existing = {
  name: gatewayName
}

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource orderingApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' existing = {
  name: orderingApiRouteName
}

resource orderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: orderingDbName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Ordering API container
//-----------------------------------------------------------------------------

resource orderingApi 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-api'
  properties: {
    application: appId
    container: {
      image: 'radius.azurecr.io/eshopdapr/ordering.api:rad-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        IdentityUrl: identityApiRoute.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/identity/'
        RetryMigrations: 'true'
        SeqServerUrl: seqRoute.properties.url
        SendConfirmationEmail: 'false'
      }
      ports: {
        http: {
          containerPort: 80
          provides: orderingApiRoute.id
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: daprAppId
        appPort: 80
        provides: daprRoute.id
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
        source: identityApiRoute.id
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
        source: seqRoute.id
      }
    }
  }
}

resource daprRoute 'Applications.Link/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'ordering-api-dapr-route'
  properties: {
    application: appId
    environment: environment
    appId: daprAppId
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output daprRouteName string = daprRoute.name

