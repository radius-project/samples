param context object

var role = last(split(context.resource.id, '/'))
var votePolicy = loadTextContent('generated/vote-ccepolicy.b64')
var platformOptions = role == 'vote' ? {
  sku: 'Confidential'
  confidentialComputeProperties: {
    ccePolicy: votePolicy
  }
} : {
  sku: 'Standard'
}

module containers 'br:ghcr.io/radius-project/azure-aci-recipes/containers:9f5f20a6b3c2b624e21d9e1a429b08bd109961d0' = {
  name: 'containers-${uniqueString(context.resource.id)}'
  scope: resourceGroup(context.azure.subscription.subscriptionId, context.azure.resourceGroup.name)
  params: {
    context: union(context, {
      resource: union(context.resource, {
        properties: union(context.resource.properties, {
          platformOptions: platformOptions
        })
      })
    })
    desiredCount: 1
    allowPlatformOptions: true
    inboundPublicIPName: '${role}-inbound'
    containerGroupProfileName: '${role}-profile'
    nGroupsParamName: '${role}-ngroup'
  }
}

output result object = containers.outputs.result
