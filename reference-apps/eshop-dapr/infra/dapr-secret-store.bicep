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

@description('The principal ID of the managed identity to grant secret access to.')
param principalId string

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
// Assign Key Vault Secrets User role to the given principal
//-----------------------------------------------------------------------------

resource keyVaultSecretsUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, principalId, keyVaultSecretsUserRoleDefinition.id)
  properties: {
    roleDefinitionId: keyVaultSecretsUserRoleDefinition.id
    principalId: principalId
    principalType: 'ServicePrincipal'
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
    mode: 'values'
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
