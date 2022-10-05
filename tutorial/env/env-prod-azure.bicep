import radius as radius

param environment string

resource redis 'Microsoft.Cache/redis@2022-05-01' = {
  name: 'redis-${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  properties: {
    sku: {
      capacity: 2
      family: 'C'
      name: 'Standard'
    }
     enableNonSslPort: true
  }
}

resource db 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'db'
  location: 'global' 
  properties: {
    mode: 'resource'
    environment: environment
    resource: redis.id
  }
}
