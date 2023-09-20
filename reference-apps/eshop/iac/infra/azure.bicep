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

var sqlPort = 1433

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

// Portable Resources ----------------------------------------------------------------------------
// TODO: Move the portable resource definitions into the application and use Recipes instead

// Need to deploy a blank rabbitmq instance to let Bicep successfully deploy
resource rabbitmq 'Applications.Messaging/rabbitMQQueues@2023-10-01-preview' = {
  name: 'eshop-event-bus'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    queue: 'eshop-event-bus'
    host: 'test'
    port: 5672
    secrets: {
      uri: 'test'
    }
  }
}

resource sqlIdentityDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
  name: 'identitydb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    database: sql::identityDb.name
    server: sql.properties.fullyQualifiedDomainName
    port: sqlPort
    username: adminLogin
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${sql.properties.fullyQualifiedDomainName},${sqlPort};Initial Catalog=${sql::identityDb.name};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    }
    resources: [
      {
        id: sql::identityDb.id
      }
    ]
  }
}

resource sqlCatalogDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
  name: 'catalogdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    database: sql::catalogDb.name
    server: sql.properties.fullyQualifiedDomainName
    port: sqlPort
    username: adminLogin
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${sql.properties.fullyQualifiedDomainName},${sqlPort};Initial Catalog=${sql::catalogDb.name};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    }
    resources: [
      {
        id: sql::catalogDb.id
      }
    ]
  }
}

resource sqlOrderingDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
  name: 'orderingdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    database: sql::orderingDb.name
    server: sql.properties.fullyQualifiedDomainName
    port: sqlPort
    username: adminLogin
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${sql.properties.fullyQualifiedDomainName},${sqlPort};Initial Catalog=${sql::orderingDb.name};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    }
    resources: [
      {
        id: sql::orderingDb.id
      }
    ]
  }
}

resource sqlWebhooksDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
  name: 'webhooksdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    database: sql::webhooksDb.name
    server: sql.properties.fullyQualifiedDomainName
    port: sqlPort
    username: adminLogin
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${sql.properties.fullyQualifiedDomainName},${sqlPort};Initial Catalog=${sql::webhooksDb.name};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    }
    resources: [
      {
        id: sql::webhooksDb.id
      }
    ]
  }
}

resource redisBasket 'Applications.Datastores/redisCaches@2023-10-01-preview' = {
  name: 'basket-data'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    host: basketCache.properties.hostName
    port: basketCache.properties.sslPort
    secrets: {
      password: basketCache.listKeys().primaryKey
      connectionString: '${basketCache.properties.hostName}:${basketCache.properties.sslPort},password=${basketCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    }
  }
}

resource redisKeystore 'Applications.Datastores/redisCaches@2023-10-01-preview' = {
  name: 'keystore-data'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
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
