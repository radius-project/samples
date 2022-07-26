import radius as radius

// Parameters --------------------------------------------
param environmentId string

param location string = resourceGroup().location

@secure()
param adminPassword string

param mongoUsername string = 'admin'

param mongoPassword string = newGuid()

resource eshop 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'eshop'
  location: location
  properties: {
    environment: environmentId
  }
}
// Gateway --------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
    name: 'gateway'
    location: location
    properties: {
      application: eshop.id
      routes: [
        http: {
          protocol: 'HTTP'
          port: 80
        }
      ]
    }
  }

resource rabbitmqContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'rabbitmq-container-eshop-event-bus'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'rabbitmq:3.9'
      env: {
        //RABBITMQ_DEFAULT_USER: username
        //RABBITMQ_DEFAULT_PASS: password
      }
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
  location: location
  properties: {
    application: eshop.id
    port: 5672
  }
}

resource rabbitmq 'Applications.Connector/rabbitmqMessageQueues@2022-03-15-privatepreview' = {
  name: 'eshop-event-bus'
  location: location
  properties: {
    application: eshop.id
    environment: environmentId
    queue: 'eshop-event-bus'
    secrets: {
      connectionString: 'amqp://${rabbitmqRoute.properties.hostname}:${rabbitmqRoute.properties.port}'
    }
  }
}

resource sqlIdentityContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-identitydb'
  location: location
  properties: {
    application: eshop.id
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
  location: location
  properties: {
    application: eshop.id
    port: 1433
  }
}

resource sqlIdentityDb 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  location: location
  properties: {
    application: eshop.id
    environment: environmentId
    server: sqlIdentityRoute.properties.hostname
    database: 'IdentityDb'
  }
}

resource sqlCatalogContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-catalogdb'
  location: location
  properties: {
    application: eshop.id
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
  location: location
  properties: {
    application: eshop.id
    port: 1433
  }
}

resource sqlCatalogDb 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  location: location
  properties: {
    application: eshop.id
    environment: environmentId
    server: sqlCatalogRoute.properties.hostname
    database: 'CatalogDb'
  }
}

resource sqlOrderingContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-orderingdb'
  location: location
  properties: {
    application: eshop.id
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
  location: location
  properties: {
    application: eshop.id
    port: 1433
  }
}

resource sqlOrderingDb 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  location: location
  properties: {
    application: eshop.id
    environment: environmentId
    server: sqlOrderingRoute.properties.hostname
    database: 'OrderingDb'
  }
}

resource sqlWebhooksContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'sql-server-webhooksdb'
  location: location
  properties: {
    application: eshop.id
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
  location: location
  properties: {
    application: eshop.id
    port: 1433
  }
}

resource sqlWebhooksDb 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  location: location
  properties: {
    application: eshop.id
    environment: environmentId
    server: sqlWebhooksRoute.properties.hostname
    database: 'WebhooksDb'
  }
}

resource redisBasketContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis-container-basket-data'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'redis:6.2'
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
  location: location
  properties: {
    application: eshop.id
    port: 6379
  }
}

resource redisBasket 'Applications.Connector/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  location: location
  properties: {
    application: eshop.id
    environment: environmentId
    host: redisBasketRoute.properties.hostname
    port: redisBasketRoute.properties.port
    secrets: {
      connectionString: '${redisBasketRoute.properties.hostname}:${redisBasketRoute.properties.port},password=},ssl=True,abortConnect=False'
      password: ''
    }
  }
}

resource redisKeystoreContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'redis-container-keystore-data'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'redis:6.2'
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
  location: location
  properties: {
    application: eshop.id
    port: 6379
  }
}

resource redisKeystore 'Applications.Connector/redisCaches@2022-03-15-privatepreview' = {
  name: 'keystore-data'
  location: location
  properties: {
    application: eshop.id
    environment: environmentId
    host: redisKeystoreRoute.properties.hostname
    port: redisKeystoreRoute.properties.port
    secrets: {
      connectionString: '${redisKeystoreRoute.properties.hostname}:${redisKeystoreRoute.properties.port},password=},ssl=True,abortConnect=False'
      password: ''
    }
  }
}
resource mongoContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'mongo-container'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'mongo:4.2'
      env: {
        MONGO_INITDB_ROOT_USERNAME: mongoUsername
        MONGO_INITDB_ROOT_PASSWORD: mongoPassword
      }
      ports: {
        mongo: {
          containerPort: 27017
          provides: mongoRoute.id
        }
      }
    }
  }
}

resource mongoRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'mongo-route'
  location: location
  properties: {
    application: eshop.id
    port: 27017
  }
}

resource mongo 'Applications.Connector/mongoDatabases@2022-03-15-privatepreview' = {
  name: 'mongo'
  location: location
  properties: {
    application: eshop.id
    environment: environmentId
    secrets: {
      connectionString: 'mongodb://${mongoUsername}:${mongoPassword}@${mongoRoute.properties.hostname}:${mongoRoute.properties.port}'
      username: mongoUsername
      password: mongoPassword
    }
  }
}