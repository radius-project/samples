targetScope = 'subscription'

@description('The existing demo prefix. Azure application/data groups are created later by Radius.')
@minLength(2)
@maxLength(20)
param prefix string

param location string

@description('Resource tenant from config.json, verified by the native bootstrap script.')
@minLength(36)
@maxLength(36)
param tenantId string

@description('Ownership marker from the private demo state for this checkout.')
@minLength(36)
@maxLength(36)
param ownerId string

@description('Object ID in the resource tenant, not the guest home-tenant object ID.')
@minLength(36)
@maxLength(36)
param adminObjectId string

@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param adminPrincipalType string = 'User'

@description('The administrator public egress CIDR. Empty or Internet-wide access is not a default.')
@minLength(9)
@maxLength(18)
param apiServerAllowedCidr string

@allowed([
  'Standard_D4s_v5'
  'Standard_D4as_v5'
  'Standard_D4s_v6'
])
param nodeVmSize string = 'Standard_D4s_v5'

@description('Empty creates a regional demo pool. The native scripts preserve existing pool zones on reruns.')
param nodeAvailabilityZones int[] = []

@description('Optional supported Kubernetes version. Empty lets AKS select its regional default at creation.')
param kubernetesVersion string = ''

var tags = {
  radiusDemoOwner: ownerId
  radiusDemoTenant: tenantId
  radiusDemoPurpose: 'aks-bootstrap'
}

resource platformGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: '${prefix}-platform'
  location: location
  tags: tags
}

module aks 'aks.bicep' = {
  name: '${prefix}-aks-bootstrap'
  scope: platformGroup
  params: {
    name: '${prefix}-aks'
    nodeResourceGroup: '${prefix}-aks-nodes'
    location: location
    tenantId: tenantId
    adminObjectId: adminObjectId
    adminPrincipalType: adminPrincipalType
    apiServerAllowedCidr: apiServerAllowedCidr
    nodeVmSize: nodeVmSize
    nodeAvailabilityZones: nodeAvailabilityZones
    kubernetesVersion: kubernetesVersion
    tags: tags
  }
}

output resourceGroupName string = platformGroup.name
output clusterName string = aks.outputs.name
output clusterId string = aks.outputs.resourceId
output nodeResourceGroupName string = '${prefix}-aks-nodes'
output controlPlaneFqdn string = aks.outputs.controlPlaneFqdn
