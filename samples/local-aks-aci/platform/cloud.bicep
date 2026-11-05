extension radius

@allowed([
  'aks'
  'aci'
])
param target string
param namespace string
param subscriptionId string
param azureResourceGroup string
param aciRecipeSource string
param kubernetesContainersRecipe string

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'voting-${target}'
  location: 'global'
  properties: {
    recipes: {
      'Radius.Compute/containers': target == 'aci' ? {
        kind: 'bicep'
        source: aciRecipeSource
      } : {
        kind: 'bicep'
        source: kubernetesContainersRecipe
        parameters: {
          externalServiceType: 'LoadBalancer'
          externalPorts: {
            'result-result': {
              web: 80
            }
            'vote-vote': {
              web: 80
            }
          }
        }
      }
      'Radius.Data/postgreSqlDatabases': {
        kind: 'bicep'
        source: 'mcr.microsoft.com/bicep/avm/res/db-for-postgre-sql/flexible-server:0.15.2'
        parameters: {
          name: 'pgsql-{{context.azure.resourceNameHash}}'
          administratorLogin: '{{context.resource.properties.username}}'
          administratorLoginPassword: '{{context.resource.properties.password}}'
          authConfig: {
            activeDirectoryAuth: 'Enabled'
            passwordAuth: 'Enabled'
          }
          skuName: 'Standard_D2ds_v5'
          tier: 'GeneralPurpose'
          databases: [
            {
              name: '{{context.resource.properties.database}}'
            }
          ]
          version: '16'
          availabilityZone: -1
          highAvailability: 'Disabled'
          geoRedundantBackup: 'Disabled'
          storageSizeGB: 32
          publicNetworkAccess: 'Enabled'
          firewallRules: [
            {
              name: 'demo-azure-services-only'
              startIpAddress: '0.0.0.0'
              endIpAddress: '0.0.0.0'
            }
          ]
          enableAdvancedThreatProtection: false
          enableTelemetry: false
          lock: {
            kind: 'None'
          }
          configurations: [
            {
              name: 'require_secure_transport'
              source: 'user-override'
              value: 'ON'
            }
          ]
        }
        outputs: {
          host: 'fqdn'
        }
      }
    }
  }
}

resource environment 'Radius.Core/environments@2025-08-01-preview' = {
  name: target
  location: 'global'
  properties: {
    providers: {
      kubernetes: {
        namespace: namespace
      }
      azure: {
        subscriptionId: subscriptionId
        resourceGroupName: azureResourceGroup
      }
    }
    recipePacks: [
      recipes.id
    ]
  }
}
