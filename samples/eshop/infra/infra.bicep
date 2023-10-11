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

// Portable Resource --------------------------------------------------------------

resource sqlIdentityDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
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

resource sqlCatalogDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
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

resource sqlOrderingDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
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

resource sqlWebhooksDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
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

resource redisKeystore 'Applications.Datastores/redisCaches@2023-10-01-preview' = {
  name: 'keystore-data'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'rediscache'
    }
  }
}

resource redisBasket 'Applications.Datastores/redisCaches@2023-10-01-preview' = {
  name: 'basket-data'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'rediscache'
    }
  }
}

resource rabbitmq 'Applications.Messaging/rabbitMQQueues@2023-10-01-preview' = if (AZURESERVICEBUSENABLED == 'False') {
  name: 'rabbitmq'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'rabbitmqmessagequeue'
    }
  }
}

resource servicebus 'Applications.Core/extenders@2023-10-01-preview' = if (AZURESERVICEBUSENABLED == 'True') {
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

@description('The name of the SQL Identity portable resource')
output sqlIdentityDb string = sqlIdentityDb.name

@description('The name of the SQL Catalog portable resource')
output sqlCatalogDb string = sqlCatalogDb.name

@description('The name of the SQL Ordering portable resource')
output sqlOrderingDb string = sqlOrderingDb.name

@description('The name of the SQL Webhooks portable resource')
output sqlWebhooksDb string = sqlWebhooksDb.name

@description('The name of the Redis Keystore portable resource')
output redisKeystore string = redisKeystore.name

@description('The name of the Redis Basket portable resource')
output redisBasket string = redisBasket.name

@description('The name of the RabbitMQ portable resource')
output rabbitmq string = rabbitmq.name

@description('The name of the Service Bus portable resource')
output servicebus string = servicebus.name

@description('Event Bus connection string')
output eventBusConnectionString string = (AZURESERVICEBUSENABLED == 'True') ? servicebus.secrets('connectionString') : rabbitmq.properties.host
