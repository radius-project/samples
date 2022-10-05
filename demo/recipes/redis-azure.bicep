param context object

resource redis 'Microsoft.Cache/redis@2022-05-01' = {
  name: 'redis-${uniqueString(context.resource.id)}'
  location: resourceGroup().location
  properties: {
    sku: {
      capacity: 2
      family: 'C'
      name: 'Standard'
    }
    enableNonSslPort: true
    minimumTlsVersion: '1.2'
  }
}

output result object = {
  values: {
    host: redis.properties.hostName
    port: redis.properties.port
    username: ''
  }
  secrets: {
    password: redis.listKeys().primaryKey
  }
}
