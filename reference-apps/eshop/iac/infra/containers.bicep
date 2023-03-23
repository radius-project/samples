import radius as rad

@description('Radius region to deploy resources into. Only global is supported today')
param ucpLocation string

@description('Radius environment ID')
param environment string

@description('Radius application ID')
param application string

@description('SQL administrator password')
@secure()
param adminPassword string

// Infrastructure -------------------------------------------------

resource rabbitmqContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'rabbitmq-container-eshop-event-bus'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'rabbitmq:3.9'
      env: {}
      ports: {
        rabbitmq: {
          containerPort: 5672
          provides: rabbitmqRoute.id
        }
      }
    }
  }
}

resource rabbitmqRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'rabbitmq-route-eshop-event-bus'
  location: ucpLocation
  properties: {
    application: application
    port: 5672
  }
}

resource sqlIdentityContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-identitydb'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'mcr.microsoft.com/mssql/server:2019-latest'
      env: {
        ACCEPT_EULA: 'Y'
        MSSQL_PID: 'Developer'
        MSSQL_SA_PASSWORD: adminPassword
      }
      ports: {
        sql: {
          containerPort: 1433
          provides: sqlIdentityRoute.id
        }
      }
    }
  }
}

resource sqlIdentityRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'sql-route-identitydb'
  location: ucpLocation
  properties: {
    application: application
    port: 1433
  }
}

resource sqlCatalogContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-catalogdb'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'mcr.microsoft.com/mssql/server:2019-latest'
      env: {
        ACCEPT_EULA: 'Y'
        MSSQL_PID: 'Developer'
        MSSQL_SA_PASSWORD: adminPassword
      }
      ports: {
        sql: {
          containerPort: 1433
          provides: sqlCatalogRoute.id
        }
      }
    }
  }
}

resource sqlCatalogRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'sql-route-catalogdb'
  location: ucpLocation
  properties: {
    application: application
    port: 1433
  }
}

resource sqlOrderingContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-orderingdb'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'mcr.microsoft.com/mssql/server:2019-latest'
      env: {
        ACCEPT_EULA: 'Y'
        MSSQL_PID: 'Developer'
        MSSQL_SA_PASSWORD: adminPassword
      }
      ports: {
        sql: {
          containerPort: 1433
          provides: sqlOrderingRoute.id
        }
      }
    }
  }
}

resource sqlOrderingRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'sql-route-orderingdb'
  location: ucpLocation
  properties: {
    application: application
    port: 1433
  }
}

resource sqlWebhooksContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-webhooksdb'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'mcr.microsoft.com/mssql/server:2019-latest'
      env: {
        ACCEPT_EULA: 'Y'
        MSSQL_PID: 'Developer'
        MSSQL_SA_PASSWORD: adminPassword
      }
      ports: {
        sql: {
          containerPort: 1433
          provides: sqlWebhooksRoute.id
        }
      }
    }
  }
}

resource sqlWebhooksRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'sql-route-webhooksdb'
  location: ucpLocation
  properties: {
    application: application
    port: 1433
  }
}

resource redisBasketContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis-container-basket-data'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'redis:6.2'
      env: {}
      ports: {
        redis: {
          containerPort: 6379
          provides: redisBasketRoute.id
        }
      }
    }
  }
}

resource redisBasketRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'redis-route-basket-data'
  location: ucpLocation
  properties: {
    application: application
    port: 6379
  }
}

resource redisKeystoreContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis-container-keystore-data'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'redis:6.2'
      env: {}
      ports: {
        redis: {
          containerPort: 6379
          provides: redisKeystoreRoute.id
        }
      }
    }
  }
}

resource redisKeystoreRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'redis-route-keystore-data'
  location: ucpLocation
  properties: {
    application: application
    port: 6379
  }
}

// Links ---------------------------------------------------------------

resource rabbitmq 'Applications.Link/rabbitmqMessageQueues@2022-03-15-privatepreview' = {
  name: 'eshop-event-bus'
  location: ucpLocation
  properties: {
    application: application
    environment: environment
    mode: 'values'
    queue: 'eshop-event-bus'
    secrets: {
      connectionString: rabbitmqRoute.properties.hostname
    }
  }
}

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  location: ucpLocation
  properties: {
    application: application
    environment: environment
    mode: 'values'
    server: sqlIdentityRoute.properties.hostname
    database: 'IdentityDb'
  }
}

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  location: ucpLocation
  properties: {
    application: application
    environment: environment
    mode: 'values'
    server: sqlCatalogRoute.properties.hostname
    database: 'CatalogDb'
  }
}

resource sqlOrderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  location: ucpLocation
  properties: {
    application: application
    environment: environment
    mode: 'values'
    server: sqlOrderingRoute.properties.hostname
    database: 'OrderingDb'
  }
}

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  location: ucpLocation
  properties: {
    application: application
    environment: environment
    mode: 'values'
    server: sqlWebhooksRoute.properties.hostname
    database: 'WebhooksDb'
  }
}

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  location: ucpLocation
  properties: {
    application: application
    environment: environment
    mode: 'values'
    host: redisBasketRoute.properties.hostname
    port: redisBasketRoute.properties.port
    secrets: {
      password: ''
    }
  }
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'keystore-data'
  location: ucpLocation
  properties: {
    application: application
    environment: environment
    mode: 'values'
    host: redisKeystoreRoute.properties.hostname
    port: redisKeystoreRoute.properties.port
    secrets: {
      password: ''
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
