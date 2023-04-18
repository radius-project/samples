import radius as rad
import az as az

@description('Azure region to deploy resources into')
param location string = resourceGroup().location

@description('Radius environment ID')
param environment string

@description('Radius application ID')
param application string

@description('SQL administrator username')
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

// Infrastructure ------------------------------------------------------------
// TODO: Move the infrastructure into Recipes

resource servicebus 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: 'eshop${uniqueString(resourceGroup().id)}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }

  resource topic 'topics' = {
    name: 'eshop_event_bus'
    properties: {
      defaultMessageTimeToLive: 'P14D'
      maxSizeInMegabytes: 1024
      requiresDuplicateDetection: false
      enableBatchedOperations: true
      supportOrdering: false
      enablePartitioning: true
      enableExpress: false
    }

    resource rootRule 'authorizationRules' = {
      name: 'Root'
      properties: {
        rights: [
          'Manage'
          'Send'
          'Listen'
        ]
      }
    }

    resource basket 'subscriptions' = {
      name: 'Basket'
      properties: {
        requiresSession: false
        defaultMessageTimeToLive: 'P14D'
        deadLetteringOnMessageExpiration: true
        deadLetteringOnFilterEvaluationExceptions: true
        maxDeliveryCount: 10
        enableBatchedOperations: true
      }
    }

    resource catalog 'subscriptions' = {
      name: 'Catalog'
      properties: {
        requiresSession: false
        defaultMessageTimeToLive: 'P14D'
        deadLetteringOnMessageExpiration: true
        deadLetteringOnFilterEvaluationExceptions: true
        maxDeliveryCount: 10
        enableBatchedOperations: true
      }
    }

    resource ordering 'subscriptions' = {
      name: 'Ordering'
      properties: {
        requiresSession: false
        defaultMessageTimeToLive: 'P14D'
        deadLetteringOnMessageExpiration: true
        deadLetteringOnFilterEvaluationExceptions: true
        maxDeliveryCount: 10
        enableBatchedOperations: true
      }
    }

    resource graceperiod 'subscriptions' = {
      name: 'GracePeriod'
      properties: {
        requiresSession: false
        defaultMessageTimeToLive: 'P14D'
        deadLetteringOnMessageExpiration: true
        deadLetteringOnFilterEvaluationExceptions: true
        maxDeliveryCount: 10
        enableBatchedOperations: true
      }
    }

    resource payment 'subscriptions' = {
      name: 'Payment'
      properties: {
        requiresSession: false
        defaultMessageTimeToLive: 'P14D'
        deadLetteringOnMessageExpiration: true
        deadLetteringOnFilterEvaluationExceptions: true
        maxDeliveryCount: 10
        enableBatchedOperations: true
      }
    }

    resource backgroundTasks 'subscriptions' = {
      name: 'backgroundtasks'
      properties: {
        requiresSession: false
        defaultMessageTimeToLive: 'P14D'
        deadLetteringOnMessageExpiration: true
        deadLetteringOnFilterEvaluationExceptions: true
        maxDeliveryCount: 10
        enableBatchedOperations: true
      }
    }

    resource OrderingSignalrHub 'subscriptions' = {
      name: 'Ordering.signalrhub'
      properties: {
        requiresSession: false
        defaultMessageTimeToLive: 'P14D'
        deadLetteringOnMessageExpiration: true
        deadLetteringOnFilterEvaluationExceptions: true
        maxDeliveryCount: 10
        enableBatchedOperations: true
      }
    }

    resource webhooks 'subscriptions' = {
      name: 'Webhooks'
      properties: {
        requiresSession: false
        defaultMessageTimeToLive: 'P14D'
        deadLetteringOnMessageExpiration: true
        deadLetteringOnFilterEvaluationExceptions: true
        maxDeliveryCount: 10
        enableBatchedOperations: true
      }
    }

  }

}

resource sql 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: 'eshopsql${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
  }

  resource allowEverything 'firewallRules' = {
    name: 'allow-everrything'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }

  resource identityDb 'databases' = {
    name: 'IdentityDb'
    location: location
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

  resource catalogDb 'databases' = {
    name: 'CatalogDb'
    location: location
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

  resource orderingDb 'databases' = {
    name: 'OrderingDb'
    location: location
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

  resource webhooksDb 'databases' = {
    name: 'WebhooksDb'
    location: location
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

}

resource keystoreCache 'Microsoft.Cache/redis@2020-12-01' = {
  name: 'eshopkeystore${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    sku: {
      family: 'C'
      capacity: 1
      name: 'Basic'
    }
  }
}

resource basketCache 'Microsoft.Cache/redis@2020-12-01' = {
  name: 'eshopbasket${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    sku: {
      family: 'C'
      capacity: 1
      name: 'Basic'
    }
  }
}

// Links ----------------------------------------------------------------------------
// TODO: Move the Link definitions into the application and use Recipes instead

// Need to deploy a blank rabbitmq instance to let Bicep successfully deploy
resource rabbitmq 'Applications.Link/rabbitmqMessageQueues@2022-03-15-privatepreview' = {
  name: 'eshop-event-bus'
  properties: {
    application: application
    environment: environment
    mode: 'values'
    queue: 'eshop-event-bus'
    secrets: {
      connectionString: 'test'
    }
  }
}

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  properties: {
    application: application
    environment: environment
    mode: 'resource'
    resource: sql::identityDb.id
  }
}

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  properties: {
    application: application
    environment: environment
    mode: 'resource'
    resource: sql::catalogDb.id
  }
}

resource sqlOrderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  properties: {
    application: application
    environment: environment
    mode: 'resource'
    resource: sql::orderingDb.id
  }
}

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  properties: {
    application: application
    environment: environment
    mode: 'resource'
    resource: sql::webhooksDb.id
  }
}

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  properties: {
    application: application
    environment: environment
    mode: 'values'
    host: basketCache.properties.hostName
    port: basketCache.properties.sslPort
    secrets: {
      password: basketCache.listKeys().primaryKey
      connectionString: '${basketCache.properties.hostName}:${basketCache.properties.sslPort},password=${basketCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    }
  }
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'keystore-data'
  properties: {
    application: application
    environment: environment
    mode: 'values'
    host: keystoreCache.properties.hostName
    port: keystoreCache.properties.sslPort
    secrets: {
      password: keystoreCache.listKeys().primaryKey
      connectionString: '${keystoreCache.properties.hostName}:${keystoreCache.properties.sslPort},password=${keystoreCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    }
  }
}

// Outputs ------------------------------------

@description('The ID of the auth rule')
#disable-next-line outputs-should-not-contain-secrets
output serviceBusAuthConnectionString string = servicebus::topic::rootRule.listKeys().primaryConnectionString

@description('The name of the RabbitMQ Queue')
output rabbitMqQueue string = rabbitmq.name

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
