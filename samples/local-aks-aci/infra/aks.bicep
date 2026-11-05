param name string
param nodeResourceGroup string
param location string
param tenantId string
param adminObjectId string
@allowed([
  'User'
  'Group'
  'ServicePrincipal'
])
param adminPrincipalType string
param apiServerAllowedCidr string
param nodeVmSize string
param nodeAvailabilityZones int[]
param kubernetesVersion string
param tags object

module cluster 'br/public:avm/res/container-service/managed-cluster:0.14.0' = {
  name: 'aks'
  params: {
    name: name
    location: location
    dnsPrefix: '${name}-${uniqueString(resourceGroup().id)}'
    nodeResourceGroup: nodeResourceGroup
    tags: tags
    enableTelemetry: false
    managedIdentities: {
      systemAssigned: true
    }
    skuName: 'Base'
    skuTier: 'Free'
    kubernetesVersion: empty(kubernetesVersion) ? null : kubernetesVersion
    enableRBAC: true
    disableLocalAccounts: true
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      tenantID: tenantId
    }
    publicNetworkAccess: 'Enabled'
    apiServerAccessProfile: {
      enablePrivateCluster: false
      authorizedIPRanges: [
        apiServerAllowedCidr
      ]
    }
    networkPlugin: 'azure'
    networkPluginMode: 'overlay'
    podCidr: '10.244.0.0/16'
    serviceCidr: '10.0.0.0/16'
    dnsServiceIP: '10.0.0.10'
    loadBalancerSku: 'standard'
    outboundType: 'loadBalancer'
    managedOutboundIPCount: 1
    // One shared pool keeps this demo small; production needs workload/system isolation.
    primaryAgentPoolProfiles: [
      {
        name: 'system'
        count: 2
        availabilityZones: nodeAvailabilityZones
        mode: 'System'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        vmSize: nodeVmSize
        osDiskType: 'Managed'
        osDiskSizeGB: 64
        maxPods: 110
        enableAutoScaling: false
        enableNodePublicIP: false
      }
    ]
    omsAgentEnabled: false
    azurePolicyEnabled: false
    enableStorageProfileDiskCSIDriver: true
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
      nodeOSUpgradeChannel: 'SecurityPatch'
    }
    roleAssignments: [
      {
        roleDefinitionIdOrName: 'Azure Kubernetes Service Cluster User Role'
        principalId: adminObjectId
        principalType: adminPrincipalType
      }
      {
        roleDefinitionIdOrName: 'Azure Kubernetes Service RBAC Cluster Admin'
        principalId: adminObjectId
        principalType: adminPrincipalType
      }
    ]
  }
}

output name string = cluster.outputs.name
output resourceId string = cluster.outputs.resourceId
output controlPlaneFqdn string = cluster.outputs.controlPlaneFQDN
