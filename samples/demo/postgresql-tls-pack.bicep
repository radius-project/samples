extension radius

@description('Name of the dedicated tutorial Recipe Pack.')
@minLength(1)
param packName string

@description('Verified TLS-capable PostgreSQL Bicep Recipe source, as registry/path:tag (no br: prefix or digest-only reference).')
@minLength(1)
param postgresqlRecipeSource string

@description('Tested Kubernetes Container Bicep Recipe source supporting Secret volumes, as registry/path:tag.')
@minLength(1)
param containerRecipeSource string

@description('Tested Kubernetes generic Secret Bicep Recipe source, as registry/path:tag.')
@minLength(1)
#disable-next-line secure-secrets-in-params
param secretRecipeSource string

var sources = {
  'Radius.Data/postgreSqlDatabases': postgresqlRecipeSource
  'Radius.Compute/containers': containerRecipeSource
  'Radius.Security/secrets': secretRecipeSource
}

resource pack 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: packName
  properties: {
    recipes: toObject(items(sources), mapping => mapping.key, mapping => {
      kind: 'bicep'
      source: (!startsWith(mapping.value, 'br:') && !contains(mapping.value, '@') && contains(mapping.value, '/') && length(split(last(split(mapping.value, '/')), ':')) == 2 && !empty(last(split(mapping.value, ':'))) && !contains(mapping.value, '://'))
        ? mapping.value
        : fail('Recipe sources must be raw registry/path:tag references, without br:, a URL scheme, or a digest.')
      // Only the isolated samples CI registry may use HTTP.
      plainHttp: startsWith(mapping.value, 'sampleregistry:5000/')
    })
  }
}
