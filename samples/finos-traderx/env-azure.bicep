extension radius

@description('Azure subscription ID the environment provisions resources into.')
param azureSubscriptionId string

@description('Azure resource group the environment provisions resources into. Must already exist.')
param azureResourceGroup string

@description('Globally-unique PostgreSQL flexible server name (3-63 lowercase alphanumerics/hyphens). The workflow generates a unique value per run.')
param serverName string

@description('Optional public IP allowed through the flexible server firewall — the CI runner egress IP, which the in-cluster app container also NATs through. Leave empty to add no firewall rule.')
param clientIpAddress string = ''

@description('OCI registry the containerImages recipe builds and pushes the TraderX service images to (e.g. `ghcr.io/myorg`).')
param containerImagesRegistry string

@description('Kubernetes Secret (in the environment namespace) holding the push registry `username`/`password`.')
param containerImagesRegistrySecretName string

@description('OCI ref for the Radius.Compute/containers recipe. Override to a custom build if needed; defaults to the released public recipe.')
param containersRecipe string = 'ghcr.io/radius-project/kube-recipes/containers:latest'

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'traderx-azure-app-avm'
  properties: {
    recipes: {
      'Radius.Data/postgreSqlDatabases': {
        kind: 'bicep'

        source: 'mcr.microsoft.com/bicep/avm/res/db-for-postgre-sql/flexible-server:0.15.2'
        parameters: {
          name: serverName

          administratorLogin: '{{context.resource.properties.username}}'
          administratorLoginPassword: '{{context.resource.properties.password}}'

          authConfig: {
            activeDirectoryAuth: 'Enabled'
            passwordAuth: 'Enabled'
          }

          firewallRules: empty(clientIpAddress) ? [] : [
            {
              name: 'e2e-runner'
              startIpAddress: clientIpAddress
              endIpAddress: clientIpAddress
            }
          ]

          skuName: '{{context.resource.properties.size == "S" ? "Standard_B1ms" : "Standard_D2ds_v5"}}'
          tier: '{{context.resource.properties.size == "S" ? "Burstable" : "GeneralPurpose"}}'

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
          enableAdvancedThreatProtection: false

          enableTelemetry: false
        }

        outputs: {
          host: 'fqdn'
        }
      }

      'Radius.Compute/containers': {
        kind: 'bicep'
        source: containersRecipe
      }

      'Radius.Security/secrets': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/secrets:latest'
      }

      'Radius.Compute/containerImages': {
        kind: 'terraform'
        source: 'git::https://github.com/radius-project/resource-types-contrib.git//Compute/containerImages/recipes/kubernetes/terraform'
        parameters: {
          registry: containerImagesRegistry
          registrySecretName: containerImagesRegistrySecretName
        }
      }
    }
  }
}

resource env 'Radius.Core/environments@2025-08-01-preview' = {
  name: 'azure'
  properties: {
    providers: {
      azure: {
        subscriptionId: azureSubscriptionId
        resourceGroupName: azureResourceGroup
      }

      kubernetes: {
        namespace: 'default'
      }
    }
    recipePacks: [
      recipes.id
    ]
  }
}
