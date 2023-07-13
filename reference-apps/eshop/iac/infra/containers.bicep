import radius as rad

@description('Radius environment ID')
param environment string

@description('Radius application ID')
param application string

@description('SQL administrator username')
param adminLogin string = 'sa'

@description('SQL administrator password')
@secure()
param adminPassword string

// Links ---------------------------------------------------------------

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'containersmssql'
      parameters: {
        database: 'IdentityDb'
        adminLogin: adminLogin
        adminPassword: adminPassword
      }
    }
  }
}

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'containersmssql'
      parameters: {
        database: 'CatalogDb'
        adminLogin: adminLogin
        adminPassword: adminPassword
      }
    }
  }
}

resource sqlOrderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'containersmssql'
      parameters: {
        database: 'OrderingDb'
        adminLogin: adminLogin
        adminPassword: adminPassword
      }
    }
  }
}

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'containersmssql'
      parameters: {
        database: 'WebhooksDb'
        adminLogin: adminLogin
        adminPassword: adminPassword
      }
    }
  }
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'keystore-data'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'containersredis'
    }
  }
}

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'containersredis'
    }
  }
}

resource rabbitmq 'Applications.Link/extenders@2022-03-15-privatepreview' = {
  name: 'rabbitmq'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'containersrabbitmq'
    }
  }
}

// Outputs ------------------------------------

@description('The name of the SQL Identity Link')
output sqlIdentityDb string = sqlIdentityDb.name

@description('The name of the SQL Catalog Link')
output sqlCatalogDb string = sqlCatalogDb.name

@description('The name of the SQL Ordering Link')
output sqlOrderingDb string = sqlOrderingDb.name

@description('The name of the SQL Webhooks Link')
output sqlWebhooksDb string = sqlWebhooksDb.name

@description('The name of the Redis Keystore Link')
output redisKeystore string = redisKeystore.name

@description('The name of the Redis Basket Link')
output redisBasket string = redisBasket.name

@description('The name of the RabbitMQ Link')
output rabbitmq string = rabbitmq.name
