extension radius

resource pack 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'postgresql-compatibility'
  properties: {
    recipes: {
      'Radius.Compute/containers': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/containers:18142182e52e19a46b0ed172037357e8e142dcd2'
        plainHttp: false
      }
      'Radius.Data/postgreSqlDatabases': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/postgresqldatabases:18142182e52e19a46b0ed172037357e8e142dcd2'
        plainHttp: false
      }
      'Radius.Security/secrets': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/secrets:18142182e52e19a46b0ed172037357e8e142dcd2'
        plainHttp: false
      }
    }
  }
}
