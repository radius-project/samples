extension radius

param namespace string
param kubernetesContainersRecipe string

var kubernetesRecipePin = loadJsonContent('../kubernetes-recipes.lock.json')

resource recipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'voting-local'
  location: 'global'
  properties: {
    recipes: {
      'Radius.Compute/containers': {
        kind: 'bicep'
        source: kubernetesContainersRecipe
        parameters: {
          externalServiceType: 'NodePort'
          externalPorts: {
            'result-result': {
              web: 30081
            }
            'vote-vote': {
              web: 30080
            }
          }
        }
      }
      'Radius.Data/postgreSqlDatabases': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/postgresqldatabases:${kubernetesRecipePin.sourceCommit}'
      }
    }
  }
}

resource environment 'Radius.Core/environments@2025-08-01-preview' = {
  name: 'local'
  location: 'global'
  properties: {
    providers: {
      kubernetes: {
        namespace: namespace
      }
    }
    recipePacks: [
      recipes.id
    ]
  }
}
