extension radius

@description('Azure subscription ID the environment provisions resources into.')
param azureSubscriptionId string

@description('Azure resource group the environment provisions resources into. Must already exist.')
param azureResourceGroup string

@description('Globally-unique MySQL flexible server name (3-63 lowercase alphanumerics/hyphens). The workflow generates a unique value per run.')
param serverName string

@description('Public IP allowed through the flexible server firewall — the CI runner egress IP, which the in-cluster app container also NATs through. The verify workflow computes it at provision time.')
param clientIpAddress string

@description('OCI ref for the Radius.Compute/containers recipe. Override to a custom build if needed; defaults to the released public recipe.')
param containersRecipe string = 'ghcr.io/radius-project/kube-recipes/containers:latest'

@description('OCI registry the containerImages recipe builds and pushes the todo-app image to (e.g. `ghcr.io/myorg`).')
param containerImagesRegistry string

@description('Kubernetes Secret (in the environment namespace) holding the push registry `username`/`password`.')
param containerImagesRegistrySecretName string

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'mysql-azure-app-avm'
  properties: {
    recipes: {
      'Radius.Data/mySqlDatabases': {
        kind: 'bicep'

        source: 'mcr.microsoft.com/bicep/avm/res/db-for-my-sql/flexible-server:0.10.3'
        parameters: {
          name: serverName

          administratorLogin: '{{context.resource.properties.username}}'
          administratorLoginPassword: '{{context.resource.properties.password}}'

          skuName: 'Standard_B1ms'
          tier: 'Burstable'

          version: '{{context.resource.properties.version == "5.7" ? "5.7" : "8.0.21"}}'

          databases: [
            {
              name: '{{context.resource.properties.database}}'
            }
          ]

          firewallRules: [
            {
              name: 'e2e-runner'
              startIpAddress: clientIpAddress
              endIpAddress: clientIpAddress
            }
          ]

          configurations: [
            {
              name: 'require_secure_transport'
              source: 'user-override'
              value: 'OFF'
            }
          ]

          availabilityZone: -1

          highAvailability: 'Disabled'
          geoRedundantBackup: 'Disabled'
          storageSizeGB: 32

          publicNetworkAccess: 'Enabled'

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

      'Radius.Compute/containerImages': {
        kind: 'terraform'
        source: 'git::https://github.com/radius-project/resource-types-contrib.git//Compute/containerImages/recipes/kubernetes/terraform?ref=b9e0fad536a53349b98f94c5be961db84845e1b7'
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
