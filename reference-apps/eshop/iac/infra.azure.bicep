// Parameters --------------------------------------------
param location string = resourceGroup().location
param adminLogin string = 'sqladmin'
@secure()
param adminPassword string

resource eshop 'radius.dev/Application@v1alpha3' = {
  name: 'eshop'

  // Gateway --------------------------------------------

  resource gateway 'Gateway' = {
    name: 'gateway'
    properties: {
      listeners: {
        http: {
          protocol: 'HTTP'
          port: 80
        }
      }
    }
  }

}

// Infrastructure

resource servicebus 'Microsoft.ServiceBus/namespaces@2021-06-01-preview' = {
  name: 'eshop${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
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

// Starters ---------------------------------------------------------

module sqlIdentity 'br:radius.azurecr.io/starters/sql-azure:latest' = {
  name: 'sql-identity'
  params: {
    adminUsername: adminLogin
    adminPassword: adminPassword
    databaseName: 'IdentityDb'
    location: location
    radiusApplication: eshop
  }
}

module sqlCatalog 'br:radius.azurecr.io/starters/sql-azure:latest' = {
  name: 'sql-catalog'
  params: {
    adminUsername: adminLogin
    adminPassword: adminPassword
    databaseName: 'CatalogDb'
    location: location
    radiusApplication: eshop
  }
}

module sqlOrdering 'br:radius.azurecr.io/starters/sql-azure:latest' = {
  name: 'sql-ordering'
  params: {
    adminUsername: adminLogin
    adminPassword: adminPassword
    databaseName: 'OrderingDb'
    location: location
    radiusApplication: eshop
  }
}

module sqlWebhooks 'br:radius.azurecr.io/starters/sql-azure:latest' = {
  name: 'sql-webhooks'
  params: {
    adminUsername: adminLogin
    adminPassword: adminPassword
    databaseName: 'WebhooksDb'
    location: location
    radiusApplication: eshop
  }
}

module redisBasket 'br:radius.azurecr.io/starters/redis-azure:latest' = {
  name: 'basket-data'
  params: {
    cacheName: 'basket-data'
    location: location
    radiusApplication: eshop
  }
}

module redisKeystore 'br:radius.azurecr.io/starters/redis-azure:latest' = {
  name: 'keystore-data'
  params: {
    cacheName: 'keystore-data'
    location: location
    radiusApplication: eshop
  }
}

module mongo 'br:radius.azurecr.io/starters/mongo-azure:latest' = {
  name: 'mongo'
  params: {
    dbName: 'mongo'
    location: location
    radiusApplication: eshop
  }
}
