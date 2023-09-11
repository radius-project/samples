import radius as rad

@description('Radius environment ID')
param environment string

@description('Radius application ID')
param application string

@description('SQL administrator password')
@secure()
param adminPassword string

var adminUsername = 'sa'

// Infrastructure -------------------------------------------------

resource rabbitmqContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'rabbitmq-container-eshop-event-bus'
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
  properties: {
    application: application
    port: 5672
  }
}

resource sqlIdentityContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-identitydb'
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
  properties: {
    application: application
    port: 1433
  }
}

resource sqlCatalogContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-catalogdb'
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
  properties: {
    application: application
    port: 1433
  }
}

resource sqlOrderingContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-orderingdb'
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
  properties: {
    application: application
    port: 1433
  }
}

resource sqlWebhooksContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-webhooksdb'
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
  properties: {
    application: application
    port: 1433
  }
}

resource redisBasketContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis-container-basket-data'
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
  properties: {
    application: application
    port: 6379
  }
}

resource redisKeystoreContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis-container-keystore-data'
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
  properties: {
    application: application
    port: 6379
  }
}

// Portable Resources ---------------------------------------------------------------

resource rabbitmq 'Applications.Messaging/rabbitMQQueues@2022-03-15-privatepreview' = {
  name: 'eshop-event-bus'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    queue: 'eshop-event-bus'
    host: rabbitmqRoute.properties.hostname
    port: rabbitmqRoute.properties.port
    username: 'guest'
    secrets: {
      password: 'guest'
    }
  }
}

resource sqlIdentityDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    server: sqlIdentityRoute.properties.hostname
    database: 'IdentityDb'
    port: sqlIdentityRoute.properties.port
    username: adminUsername
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${sqlIdentityRoute.properties.hostname},${sqlIdentityRoute.properties.port};Initial Catalog=IdentityDb;User Id=${adminUsername};Password=${adminPassword};Encrypt=false'
    }
  }
}

resource sqlCatalogDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    server: sqlCatalogRoute.properties.hostname
    database: 'CatalogDb'
    port: sqlCatalogRoute.properties.port
    username: adminUsername
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${sqlCatalogRoute.properties.hostname},${sqlCatalogRoute.properties.port};Initial Catalog=CatalogDb;User Id=${adminUsername};Password=${adminPassword};Encrypt=false'
    }
  }
}

resource sqlOrderingDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    server: sqlOrderingRoute.properties.hostname
    database: 'OrderingDb'
    port: sqlOrderingRoute.properties.port
    username: adminUsername
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${sqlOrderingRoute.properties.hostname},${sqlOrderingRoute.properties.port};Initial Catalog=OrderingDb;User Id=${adminUsername};Password=${adminPassword};Encrypt=false'
    }
  }
}

resource sqlWebhooksDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    server: sqlWebhooksRoute.properties.hostname
    database: 'WebhooksDb'
    port: sqlWebhooksRoute.properties.port
    username: adminUsername
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${sqlWebhooksRoute.properties.hostname},${sqlWebhooksRoute.properties.port};Initial Catalog=WebhooksDb;User Id=${adminUsername};Password=${adminPassword};Encrypt=false'
    }
  }
}

resource redisBasket 'Applications.Datastores/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    host: redisBasketRoute.properties.hostname
    port: redisBasketRoute.properties.port
    secrets: {
      connectionString: '${redisBasketRoute.properties.hostname}:${redisBasketRoute.properties.port},abortConnect=False'
    }
  }
}

resource redisKeystore 'Applications.Datastores/redisCaches@2022-03-15-privatepreview' = {
  name: 'keystore-data'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    host: redisKeystoreRoute.properties.hostname
    port: redisKeystoreRoute.properties.port
    secrets: {
      connectionString: '${redisKeystoreRoute.properties.hostname}:${redisKeystoreRoute.properties.port},abortConnect=False'
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
