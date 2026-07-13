extension radius

@description('The ID of the Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('PostgreSQL admin password shared by the eShop databases. Radius encrypts it and injects it into the recipe and the application secret.')
@secure()
param databasePassword string

@description('RabbitMQ password for the eShop event bus. Radius encrypts it and injects it into the event bus secret.')
@secure()
param eventBusPassword string

@description('Externally reachable URL for identity-api. Set to the public hostname of the identity-api route so the browser and services can reach the OIDC endpoints.')
param identityUrl string

@description('Externally reachable URL for webapp. Set to the public hostname of the webapp route (used as its OIDC callback).')
param webAppUrl string

@description('Externally reachable URL for webhooksclient. Set to the public hostname of the webhooksclient route (used as its OIDC callback).')
param webhooksClientUrl string

@description('Tag applied to the eShop service images built from source. Defaults to the pinned upstream commit.')
param imageTag string = '9b4f9434f46fdc5c1a6e9e936af2868340cdbc48'

@description('Build context for the eShop service images. Defaults to the source directory published alongside this sample.')
param source string = 'git::https://github.com/radius-project/samples.git//samples/dotnet-eshop/src?ref=edge'

@description('Optional single target platform for the image builds (e.g. `linux/amd64`). Empty builds the default multi-architecture images.')
param buildPlatform string = ''

var eshopCommit = '9b4f9434f46fdc5c1a6e9e936af2868340cdbc48'
var databaseUsername = 'eshop'
var eventBusUsername = 'eshop'
var servicePort = 8080

var buildPlatforms = empty(buildPlatform) ? [
  'linux/amd64'
  'linux/arm64'
] : [
  buildPlatform
]

resource eshopApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'eshop'
  properties: {
    environment: environment
  }
}

resource catalogDatabase 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'catalogdb'
  properties: {
    environment: environment
    application: eshopApp.id
    size: 'S'
    database: 'catalogdb'
    username: databaseUsername
    password: databasePassword
  }
}

resource identityDatabase 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'identitydb'
  properties: {
    environment: environment
    application: eshopApp.id
    size: 'S'
    database: 'identitydb'
    username: databaseUsername
    password: databasePassword
  }
}

resource orderingDatabase 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'orderingdb'
  properties: {
    environment: environment
    application: eshopApp.id
    size: 'S'
    database: 'orderingdb'
    username: databaseUsername
    password: databasePassword
  }
}

resource webhooksDatabase 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'webhooksdb'
  properties: {
    environment: environment
    application: eshopApp.id
    size: 'S'
    database: 'webhooksdb'
    username: databaseUsername
    password: databasePassword
  }
}

resource dbSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'dbsecret'
  properties: {
    environment: environment
    application: eshopApp.id
    data: {
      CONNECTIONSTRINGS__CATALOGDB: {
        value: 'Host=${catalogDatabase.properties.host};Port=5432;Database=catalogdb;Username=${databaseUsername};Password=${databasePassword};SSL Mode=Require;Trust Server Certificate=true'
      }
      CONNECTIONSTRINGS__IDENTITYDB: {
        value: 'Host=${identityDatabase.properties.host};Port=5432;Database=identitydb;Username=${databaseUsername};Password=${databasePassword};SSL Mode=Require;Trust Server Certificate=true'
      }
      CONNECTIONSTRINGS__ORDERINGDB: {
        value: 'Host=${orderingDatabase.properties.host};Port=5432;Database=orderingdb;Username=${databaseUsername};Password=${databasePassword};SSL Mode=Require;Trust Server Certificate=true'
      }
      CONNECTIONSTRINGS__WEBHOOKSDB: {
        value: 'Host=${webhooksDatabase.properties.host};Port=5432;Database=webhooksdb;Username=${databaseUsername};Password=${databasePassword};SSL Mode=Require;Trust Server Certificate=true'
      }
    }
  }
}

resource eventBusSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'eventbus-secret'
  properties: {
    environment: environment
    application: eshopApp.id
    data: {
      EVENTBUS_CONNECTION: {
        value: 'amqp://${eventBusUsername}:${eventBusPassword}@eventbus:5672'
      }
      RABBITMQ_PASSWORD: {
        value: eventBusPassword
      }
    }
  }
}

resource identityImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'identity-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/Identity.API/Identity.API.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'Identity.API.dll'
      }
    }
  }
}

resource basketImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'basket-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/Basket.API/Basket.API.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'Basket.API.dll'
      }
    }
  }
}

resource catalogImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'catalog-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/Catalog.API/Catalog.API.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'Catalog.API.dll'
      }
    }
  }
}

resource orderingImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'ordering-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/Ordering.API/Ordering.API.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'Ordering.API.dll'
      }
    }
  }
}

resource orderProcessorImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'order-processor-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/OrderProcessor/OrderProcessor.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'OrderProcessor.dll'
      }
    }
  }
}

resource paymentProcessorImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'payment-processor-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/PaymentProcessor/PaymentProcessor.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'PaymentProcessor.dll'
      }
    }
  }
}

resource webhooksApiImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'webhooks-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/Webhooks.API/Webhooks.API.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'Webhooks.API.dll'
      }
    }
  }
}

resource webhooksClientImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'webhooksclient-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/WebhookClient/WebhookClient.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'WebhookClient.dll'
      }
    }
  }
}

resource webAppImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'webapp-image'
  properties: {
    environment: environment
    application: eshopApp.id
    tag: imageTag
    build: {
      source: source
      dockerfile: 'Dockerfile'
      platforms: buildPlatforms
      args: {
        PROJECT: 'src/WebApp/WebApp.csproj'
        ESHOP_COMMIT: eshopCommit
        ENTRY_DLL: 'WebApp.dll'
      }
    }
  }
}

resource redisContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'redis'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      redis: {
        image: 'redis:8-alpine'
        ports: {
          redis: {
            containerPort: 6379
          }
        }
      }
    }
  }
}

resource eventBusContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'eventbus'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      rabbitmq: {
        image: 'rabbitmq:4-management-alpine'
        ports: {
          amqp: {
            containerPort: 5672
          }
          management: {
            containerPort: 15672
          }
        }
        env: {
          RABBITMQ_DEFAULT_USER: {
            value: eventBusUsername
          }
          RABBITMQ_DEFAULT_PASS: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBusSecret.name
                key: 'RABBITMQ_PASSWORD'
              }
            }
          }
        }
      }
    }
  }
}

resource identityContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'identity-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      identityApi: {
        image: identityImage.properties.imageReference
        ports: {
          web: {
            containerPort: servicePort
          }
        }
        env: {
          ASPNETCORE_URLS: {
            value: 'http://+:${servicePort}'
          }
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          ConnectionStrings__identitydb: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'CONNECTIONSTRINGS__IDENTITYDB'
              }
            }
          }
          BasketApiClient: {
            value: 'http://basket-api:${servicePort}'
          }
          OrderingApiClient: {
            value: 'http://ordering-api:${servicePort}'
          }
          WebhooksApiClient: {
            value: 'http://webhooks-api:${servicePort}'
          }
          WebhooksWebClient: {
            value: webhooksClientUrl
          }
          WebAppClient: {
            value: webAppUrl
          }
        }
      }
    }
    connections: {
      identitydb: {
        source: identityDatabase.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource basketContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'basket-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      basketApi: {
        image: basketImage.properties.imageReference
        ports: {
          grpc: {
            containerPort: servicePort
          }
        }
        env: {
          ASPNETCORE_URLS: {
            value: 'http://+:${servicePort}'
          }
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          ConnectionStrings__redis: {
            value: 'redis:6379'
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBusSecret.name
                key: 'EVENTBUS_CONNECTION'
              }
            }
          }
          Identity__Url: {
            value: identityUrl
          }
        }
      }
    }
    connections: {
      redis: {
        source: redisContainer.id
        disableDefaultEnvVars: true
      }
      eventbus: {
        source: eventBusContainer.id
        disableDefaultEnvVars: true
      }
      identityApi: {
        source: identityContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource catalogContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'catalog-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      catalogApi: {
        image: catalogImage.properties.imageReference
        ports: {
          web: {
            containerPort: servicePort
          }
        }
        env: {
          ASPNETCORE_URLS: {
            value: 'http://+:${servicePort}'
          }
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          ConnectionStrings__catalogdb: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'CONNECTIONSTRINGS__CATALOGDB'
              }
            }
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBusSecret.name
                key: 'EVENTBUS_CONNECTION'
              }
            }
          }
        }
      }
    }
    connections: {
      catalogdb: {
        source: catalogDatabase.id
        disableDefaultEnvVars: true
      }
      eventbus: {
        source: eventBusContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource orderingContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'ordering-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      orderingApi: {
        image: orderingImage.properties.imageReference
        ports: {
          web: {
            containerPort: servicePort
          }
        }
        env: {
          ASPNETCORE_URLS: {
            value: 'http://+:${servicePort}'
          }
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          ConnectionStrings__orderingdb: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'CONNECTIONSTRINGS__ORDERINGDB'
              }
            }
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBusSecret.name
                key: 'EVENTBUS_CONNECTION'
              }
            }
          }
          Identity__Url: {
            value: identityUrl
          }
        }
      }
    }
    connections: {
      orderingdb: {
        source: orderingDatabase.id
        disableDefaultEnvVars: true
      }
      eventbus: {
        source: eventBusContainer.id
        disableDefaultEnvVars: true
      }
      identityApi: {
        source: identityContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource orderProcessorContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'order-processor'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      orderProcessor: {
        image: orderProcessorImage.properties.imageReference
        env: {
          ConnectionStrings__orderingdb: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'CONNECTIONSTRINGS__ORDERINGDB'
              }
            }
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBusSecret.name
                key: 'EVENTBUS_CONNECTION'
              }
            }
          }
        }
      }
    }
    connections: {
      orderingdb: {
        source: orderingDatabase.id
        disableDefaultEnvVars: true
      }
      eventbus: {
        source: eventBusContainer.id
        disableDefaultEnvVars: true
      }
      orderingApi: {
        source: orderingContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource paymentProcessorContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'payment-processor'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      paymentProcessor: {
        image: paymentProcessorImage.properties.imageReference
        env: {
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBusSecret.name
                key: 'EVENTBUS_CONNECTION'
              }
            }
          }
        }
      }
    }
    connections: {
      eventbus: {
        source: eventBusContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource webhooksApiContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'webhooks-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      webhooksApi: {
        image: webhooksApiImage.properties.imageReference
        ports: {
          web: {
            containerPort: servicePort
          }
        }
        env: {
          ASPNETCORE_URLS: {
            value: 'http://+:${servicePort}'
          }
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          ConnectionStrings__webhooksdb: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'CONNECTIONSTRINGS__WEBHOOKSDB'
              }
            }
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBusSecret.name
                key: 'EVENTBUS_CONNECTION'
              }
            }
          }
          Identity__Url: {
            value: identityUrl
          }
        }
      }
    }
    connections: {
      webhooksdb: {
        source: webhooksDatabase.id
        disableDefaultEnvVars: true
      }
      eventbus: {
        source: eventBusContainer.id
        disableDefaultEnvVars: true
      }
      identityApi: {
        source: identityContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource webhooksClientContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'webhooksclient'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      webhooksClient: {
        image: webhooksClientImage.properties.imageReference
        ports: {
          web: {
            containerPort: servicePort
          }
        }
        env: {
          ASPNETCORE_URLS: {
            value: 'http://+:${servicePort}'
          }
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          IdentityUrl: {
            value: identityUrl
          }
          CallBackUrl: {
            value: webhooksClientUrl
          }
          'services__webhooks-api__http__0': {
            value: 'http://webhooks-api:${servicePort}'
          }
        }
      }
    }
    connections: {
      webhooksApi: {
        source: webhooksApiContainer.id
        disableDefaultEnvVars: true
      }
      identityApi: {
        source: identityContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource webAppContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'webapp'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      webapp: {
        image: webAppImage.properties.imageReference
        ports: {
          web: {
            containerPort: servicePort
          }
        }
        env: {
          ASPNETCORE_URLS: {
            value: 'http://+:${servicePort}'
          }
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBusSecret.name
                key: 'EVENTBUS_CONNECTION'
              }
            }
          }
          IdentityUrl: {
            value: identityUrl
          }
          CallBackUrl: {
            value: webAppUrl
          }
          'services__basket-api__http__0': {
            value: 'http://basket-api:${servicePort}'
          }
          'services__catalog-api__http__0': {
            value: 'http://catalog-api:${servicePort}'
          }
          'services__ordering-api__http__0': {
            value: 'http://ordering-api:${servicePort}'
          }
        }
      }
    }
    connections: {
      basketApi: {
        source: basketContainer.id
        disableDefaultEnvVars: true
      }
      catalogApi: {
        source: catalogContainer.id
        disableDefaultEnvVars: true
      }
      orderingApi: {
        source: orderingContainer.id
        disableDefaultEnvVars: true
      }
      eventbus: {
        source: eventBusContainer.id
        disableDefaultEnvVars: true
      }
      identityApi: {
        source: identityContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource identityRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'identity-api'
  properties: {
    environment: environment
    application: eshopApp.id
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: identityContainer.id
          containerName: 'identityApi'
          containerPort: servicePort
        }
      }
    ]
  }
}

resource webAppRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'webapp'
  properties: {
    environment: environment
    application: eshopApp.id
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: webAppContainer.id
          containerName: 'webapp'
          containerPort: servicePort
        }
      }
    ]
  }
}

resource webhooksClientRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'webhooksclient'
  properties: {
    environment: environment
    application: eshopApp.id
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: webhooksClientContainer.id
          containerName: 'webhooksClient'
          containerPort: servicePort
        }
      }
    ]
  }
}
