import radius as radius

@description('The Radius application ID.')
param appId string

@description('The Radius environment name.')
param environment string

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The unique seed used to generate resource names.')
param uniqueSeed string = resourceGroup().id

@description('The name of the key vault.')
param keyVaultName string = 'keyvault-${uniqueString(uniqueSeed)}'

@description('The name of the Key Vault SKU.')
@allowed([
  'standard'
  'premium'
])
param skuName string = 'standard'

@description('The Azure Active Directory tenant ID that should be used for authenticating requests to the key vault.')
param tenantId string = subscription().tenantId

//-----------------------------------------------------------------------------
// Create the Key Vault
//-----------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: tenantId
    enableRbacAuthorization: true
    sku: {
      name: skuName
      family: 'A'
    }
  }
}

//-----------------------------------------------------------------------------
// Create the Dapr secret store component
//-----------------------------------------------------------------------------

resource daprSecretStore 'Applications.Link/daprSecretStores@2022-03-15-privatepreview' = {
  name: 'eshopondapr-secretstore'
  location: 'global'
  properties: {
    application: appId
    environment: environment
    resourceProvisioning: 'manual'
    type: 'secretstores.azure.keyvault'
    version: 'v1'
    metadata: {
      vaultName: keyVaultName
    }
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output keyVaultName string = keyVault.name
output daprSecretStoreName string = daprSecretStore.name
