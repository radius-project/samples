extension radius

@description('Name of the legacy sample environment.')
param name string

@description('Kubernetes namespace for the legacy samples.')
param namespace string

// Keep legacy samples independent of the resource type targeted by 'rad env create'.
resource environment 'Applications.Core/environments@2023-10-01-preview' = {
  name: name
  location: 'global'
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: namespace
    }
  }
}
