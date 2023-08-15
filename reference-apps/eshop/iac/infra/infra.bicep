import radius as rad

@description('Radius environment ID')
param environment string

@description('Radius application ID')
param application string

@description('SQL administrator username')
@secure()
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

@description('Use Azure Service Bus for messaging. Allowed values: "True", "False".')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

// Links ---------------------------------------------------------------

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'sqldatabase'
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
      name: 'sqldatabase'
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
      name: 'sqldatabase'
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
      name: 'sqldatabase'
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
      name: 'rediscache'
    }
  }
}

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'rediscache'
    }
  }
}

resource rabbitmq 'Applications.Link/rabbitMQMessageQueues@2022-03-15-privatepreview' = if (AZURESERVICEBUSENABLED == 'False') {
  name: 'rabbitmq'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'rabbitmqmessagequeue'
    }
  }
}

resource servicebus 'Applications.Link/extenders@2022-03-15-privatepreview' = if (AZURESERVICEBUSENABLED == 'True') {
  name: 'servicebus'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'servicebus'
      parameters: {
        topicName: 'eshop_event_bus'
        subscriptions: ['Basket', 'Catalog', 'Ordering', 'GracePeriod', 'Payment', 'backgroundtasks', 'Ordering.signalrhub', 'Webhooks']
      }
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

@description('The name of the Service Bus Link')
output servicebus string = servicebus.name

@description('Event Bus connection string')
output eventBusConnectionString string = (AZURESERVICEBUSENABLED == 'True') ? servicebus.secrets('connectionString') : rabbitmq.properties.host
