extension radius

@description('Azure subscription ID the environment provisions resources into.')
param azureSubscriptionId string

@description('Azure resource group the environment provisions resources into. Must already exist.')
param azureResourceGroup string

@description('Globally-unique Azure Storage account name (3-24 lowercase letters/numbers, no hyphens). The workflow generates a unique value per run.')
param uniqueName string

@description('OCI ref for the Radius.Compute/containers recipe. Override to a custom build if needed; defaults to the released public recipe.')
param containersRecipe string = 'ghcr.io/radius-project/kube-recipes/containers:latest'

@description('OCI registry the containerImages recipe builds and pushes the sftpgo image to (e.g. `ghcr.io/myorg`).')
param containerImagesRegistry string

@description('Kubernetes Secret (in the environment namespace) holding the push registry `username`/`password`.')
param containerImagesRegistrySecretName string

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'storage-azure-avm'
  properties: {
    recipes: {
      'Radius.Storage/objectStorage': {
        kind: 'bicep'

        source: 'mcr.microsoft.com/bicep/avm/res/storage/storage-account:0.32.1'
        parameters: {
          name: uniqueName

          kind: 'StorageV2'
          skuName: 'Standard_LRS'

          allowBlobPublicAccess: false

          networkAcls: {
            bypass: 'AzureServices'
            defaultAction: 'Allow'
          }

          blobServices: {
            containers: [
              {
                name: '{{context.resource.properties.containerName}}'
              }
            ]
          }

          enableTelemetry: false
        }

        outputs: {
          endpoint: 'primaryBlobEndpoint'
          accountName: 'name'
          secrets: {
            connectionString: 'primaryConnectionString'
            accountKey: 'primaryAccessKey'
          }
        }
      }

      'Radius.Security/secrets': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/secrets:latest'
      }

      'Radius.Compute/containers': {
        kind: 'bicep'
        source: containersRecipe
      }

      'Radius.Compute/containerImages': {
        kind: 'terraform'
        source: 'git::https://github.com/radius-project/resource-types-contrib.git//Compute/containerImages/recipes/kubernetes/terraform?ref=7f5375bf89305d7641ff645336841618b305daf8'
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
