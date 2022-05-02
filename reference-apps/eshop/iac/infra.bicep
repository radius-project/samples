// Parameters --------------------------------------------
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

// Starters ---------------------------------------------------------

module rabbitMQ 'br:radius.azurecr.io/starters/rabbitmq:latest' = {
  name: 'rabbitmq'
  params: {
    queueName: 'eshop_event_bus'
    radiusApplication: eshop
  }
}

module sqlIdentity 'br:radius.azurecr.io/starters/sql:latest' = {
  name: 'sql-identity'
  params: {
    adminPassword: adminPassword
    databaseName: 'IdentityDb'
    radiusApplication: eshop
  }
}

module sqlCatalog 'br:radius.azurecr.io/starters/sql:latest' = {
  name: 'sql-catalog'
  params: {
    adminPassword: adminPassword
    databaseName: 'CatalogDb'
    radiusApplication: eshop
  }
}

module sqlOrdering 'br:radius.azurecr.io/starters/sql:latest' = {
  name: 'sql-ordering'
  params: {
    adminPassword: adminPassword
    databaseName: 'OrderingDb'
    radiusApplication: eshop
  }
}

module sqlWebhooks 'br:radius.azurecr.io/starters/sql:latest' = {
  name: 'sql-webhooks'
  params: {
    adminPassword: adminPassword
    databaseName: 'WebhooksDb'
    radiusApplication: eshop
  }
}

module redisBasket 'br:radius.azurecr.io/starters/redis:latest' = {
  name: 'basket-data'
  params: {
    cacheName: 'basket-data'
    radiusApplication: eshop
  }
}

module redisKeystore 'br:radius.azurecr.io/starters/redis:latest' = {
  name: 'keystore-data'
  params: {
    cacheName: 'keystore-data'
    radiusApplication: eshop
  }
}

module mongo 'br:radius.azurecr.io/starters/mongo:latest' = {
  name: 'mongo'
  params: {
    dbName: 'mongo'
    radiusApplication: eshop
  }
}
