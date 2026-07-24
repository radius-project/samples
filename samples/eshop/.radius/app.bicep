extension radius

param environment string

@secure()
param postgresPassword string

@description('Image tag injected by the deploy workflow (commit SHA). Containers build from build.source, so this is used only as a build/version marker.')
param image string = ''

resource eshopApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'eshop'
  properties: {
    environment: environment
  }
}

resource catalogDb 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'catalogdb'
  properties: {
    environment: environment
    application: eshopApp.id
    database: 'catalogdb'
    size: 'S'
    username: 'myadmin'
    password: postgresPassword
    codeReference: 'src/eShop.AppHost/Program.cs#L15'
  }
}

resource identityDb 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'identitydb'
  properties: {
    environment: environment
    application: eshopApp.id
    database: 'identitydb'
    size: 'S'
    username: 'myadmin'
    password: postgresPassword
    codeReference: 'src/eShop.AppHost/Program.cs#L16'
  }
}

resource orderingDb 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'orderingdb'
  properties: {
    environment: environment
    application: eshopApp.id
    database: 'orderingdb'
    size: 'S'
    username: 'myadmin'
    password: postgresPassword
    codeReference: 'src/eShop.AppHost/Program.cs#L17'
  }
}

resource webhooksDb 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'webhooksdb'
  properties: {
    environment: environment
    application: eshopApp.id
    database: 'webhooksdb'
    size: 'S'
    username: 'myadmin'
    password: postgresPassword
    codeReference: 'src/eShop.AppHost/Program.cs#L18'
  }
}

resource redisCache 'Radius.Data/redisCaches@2025-08-01-preview' = {
  name: 'eshop-redis-reabdul'
  properties: {
    environment: environment
    application: eshopApp.id
    size: 'S'
    codeReference: 'src/eShop.AppHost/Program.cs#L7'
  }
}

resource eventBus 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'eshop-eventbus-reabdul'
  properties: {
    environment: environment
    application: eshopApp.id
    queue: 'eventbus'
    codeReference: 'src/eShop.AppHost/Program.cs#L8'
  }
}

resource identityImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'identity-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/Identity.API/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/Identity.API/Dockerfile'
  }
}

resource basketImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'basket-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/Basket.API/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/Basket.API/Dockerfile'
  }
}

resource catalogImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'catalog-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/Catalog.API/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/Catalog.API/Dockerfile'
  }
}

resource orderingImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'ordering-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/Ordering.API/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/Ordering.API/Dockerfile'
  }
}

resource orderProcessorImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'order-processor-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/OrderProcessor/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/OrderProcessor/Dockerfile'
  }
}

resource paymentProcessorImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'payment-processor-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/PaymentProcessor/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/PaymentProcessor/Dockerfile'
  }
}

resource webhooksImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'webhooks-api-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/Webhooks.API/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/Webhooks.API/Dockerfile'
  }
}

resource webhooksClientImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'webhooksclient-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/WebhookClient/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/WebhookClient/Dockerfile'
  }
}

resource webAppImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'webapp-image'
  properties: {
    environment: environment
    application: eshopApp.id
    build: {
      source: 'git::https://github.com/radius-project/samples.git//samples/eshop?ref=reshrahim/eshop-refresh'
      dockerfile: 'src/WebApp/Dockerfile'
      platforms: ['linux/amd64']
    }
    codeReference: 'src/WebApp/Dockerfile'
  }
}

resource identityContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'identity-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      identity: {
        image: identityImage.properties.imageReference
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          ConnectionStrings__identitydb: {
            value: 'Host=${identityDb.properties.host};Port=5432;Database=identitydb;Username=myadmin;Password=${postgresPassword}'
          }
          // OIDC client redirect-URI registration; must be each client's browser-facing URL.
          // Full sign-in requires trusted HTTPS (ingress/TLS) - see notes at end of file.
          // Honor X-Forwarded-Proto from a TLS-terminating ingress so IdentityServer emits
          // an https issuer/authority (required for sign-in behind HTTPS ingress).
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          WebAppClient: {
            value: 'http://webapp-webapp:8080'
          }
          WebhooksWebClient: {
            value: 'http://webhooksclient-webhooksclient:8080'
          }
        }
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      identitydb: {
        source: identityDb.id
      }
    }
    codeReference: 'src/Identity.API/Program.cs'
  }
}

resource basketContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'basket-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      basket: {
        image: basketImage.properties.imageReference
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          Identity__Url: {
            value: 'http://identity-api-identity:8080'
          }
          ConnectionStrings__redis: {
            valueFrom: {
              secretKeyRef: {
                secretName: redisCache.properties.secrets.name
                key: 'url'
              }
            }
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBus.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      redis: {
        source: redisCache.id
      }
      rabbitmq: {
        source: eventBus.id
      }
      identity: {
        source: identityContainer.id
      }
    }
    codeReference: 'src/Basket.API/Program.cs'
  }
}

resource catalogContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'catalog-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      catalog: {
        image: catalogImage.properties.imageReference
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          ConnectionStrings__catalogdb: {
            value: 'Host=${catalogDb.properties.host};Port=5432;Database=catalogdb;Username=myadmin;Password=${postgresPassword}'
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBus.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      catalogdb: {
        source: catalogDb.id
      }
      rabbitmq: {
        source: eventBus.id
      }
    }
    codeReference: 'src/Catalog.API/Program.cs'
  }
}

resource orderingContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'ordering-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      ordering: {
        image: orderingImage.properties.imageReference
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          Identity__Url: {
            value: 'http://identity-api-identity:8080'
          }
          ConnectionStrings__orderingdb: {
            value: 'Host=${orderingDb.properties.host};Port=5432;Database=orderingdb;Username=myadmin;Password=${postgresPassword}'
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBus.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      orderingdb: {
        source: orderingDb.id
      }
      rabbitmq: {
        source: eventBus.id
      }
      identity: {
        source: identityContainer.id
      }
    }
    codeReference: 'src/Ordering.API/Program.cs'
  }
}

resource orderProcessorContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'order-processor'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      'order-processor': {
        image: orderProcessorImage.properties.imageReference
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          ConnectionStrings__orderingdb: {
            value: 'Host=${orderingDb.properties.host};Port=5432;Database=orderingdb;Username=myadmin;Password=${postgresPassword}'
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBus.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
      }
    }
    connections: {
      orderingdb: {
        source: orderingDb.id
      }
      rabbitmq: {
        source: eventBus.id
      }
      ordering: {
        source: orderingContainer.id
      }
    }
    codeReference: 'src/OrderProcessor/Program.cs'
  }
}

resource paymentProcessorContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'payment-processor'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      'payment-processor': {
        image: paymentProcessorImage.properties.imageReference
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBus.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
      }
    }
    connections: {
      rabbitmq: {
        source: eventBus.id
      }
    }
    codeReference: 'src/PaymentProcessor/Program.cs'
  }
}

resource webhooksContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'webhooks-api'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      webhooks: {
        image: webhooksImage.properties.imageReference
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          Identity__Url: {
            value: 'http://identity-api-identity:8080'
          }
          ConnectionStrings__webhooksdb: {
            value: 'Host=${webhooksDb.properties.host};Port=5432;Database=webhooksdb;Username=myadmin;Password=${postgresPassword}'
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBus.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      webhooksdb: {
        source: webhooksDb.id
      }
      rabbitmq: {
        source: eventBus.id
      }
      identity: {
        source: identityContainer.id
      }
    }
    codeReference: 'src/Webhooks.API/Program.cs'
  }
}

resource webhooksClientContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'webhooksclient'
  properties: {
    environment: environment
    application: eshopApp.id
    containers: {
      webhooksclient: {
        image: webhooksClientImage.properties.imageReference
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          IdentityUrl: {
            value: 'http://identity-api-identity:8080'
          }
          CallBackUrl: {
            value: 'http://webhooksclient-webhooksclient:8080'
          }
          // Aspire service discovery -> real Radius service DNS (<container>-<containerName>)
          'services__webhooks-api__http__0': {
            value: 'http://webhooks-api-webhooks:8080'
          }
        }
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      webhooks: {
        source: webhooksContainer.id
      }
      identity: {
        source: identityContainer.id
      }
    }
    codeReference: 'src/WebhookClient/Program.cs'
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
        env: {
          ASPNETCORE_ENVIRONMENT: {
            value: 'Development'
          }
          IdentityUrl: {
            value: 'http://identity-api-identity:8080'
          }
          CallBackUrl: {
            value: 'http://webapp-webapp:8080'
          }
          // Honor X-Forwarded-Proto from a TLS-terminating ingress so OIDC correlation/
          // redirect URLs use https (required for sign-in behind HTTPS ingress).
          ASPNETCORE_FORWARDEDHEADERS_ENABLED: {
            value: 'true'
          }
          // Aspire service discovery -> real Radius service DNS (<container>-<containerName>)
          'services__catalog-api__http__0': {
            value: 'http://catalog-api-catalog:8080'
          }
          'services__ordering-api__http__0': {
            value: 'http://ordering-api-ordering:8080'
          }
          'services__basket-api__http__0': {
            value: 'http://basket-api-basket:8080'
          }
          ConnectionStrings__eventbus: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventBus.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      basket: {
        source: basketContainer.id
      }
      catalog: {
        source: catalogContainer.id
      }
      ordering: {
        source: orderingContainer.id
      }
      rabbitmq: {
        source: eventBus.id
      }
      identity: {
        source: identityContainer.id
      }
    }
    codeReference: 'src/WebApp/Program.cs'
  }
}

// -----------------------------------------------------------------------------
// Known gaps that CANNOT be expressed in this model today (tracked as Radius bugs):
//
// 1. pgvector on Azure Postgres: Catalog.API requires the `vector` extension, but
//    the postgreSqlDatabases recipe exposes no way to set the server's
//    `azure.extensions` allow-list. Must be applied out-of-band, e.g.:
//      az postgres flexible-server parameter set -g <rg> -s <catalog-server> \
//        --name azure.extensions --value vector
//
// 2. Public ingress / stable HTTPS URL for sign-in: containers are only reachable via
//    cluster DNS (<container>-<containerName>:8080). Radius cannot model a LoadBalancer/
//    Ingress or obtain a stable external URL, and Radius.Compute/routes only attaches an
//    HTTPRoute to a PRE-EXISTING Gateway (no controller/LB/TLS-cert provisioning).
//    The URL values above (WebAppClient/CallBackUrl/IdentityUrl) use cluster DNS, which is
//    fine for anonymous browsing + service-to-service, but full OIDC sign-in needs trusted
//    HTTPS on a stable hostname. Verified working sign-in recipe (applied out-of-band):
//      a. Install an ingress controller (ingress-nginx) + cert-manager + a Let's Encrypt
//         ClusterIssuer (HTTP-01).
//      b. Create Ingress objects for webapp-webapp:8080 and identity-api-identity:8080 with
//         TLS, using sslip.io hostnames derived from the ingress LB IP
//         (webapp.<LB-IP>.sslip.io, identity.<LB-IP>.sslip.io).
//      c. Set ASPNETCORE_FORWARDEDHEADERS_ENABLED=true (done above for identity + webapp) so
//         IdentityServer emits an https issuer that matches the browser-facing authority.
//      d. Point IdentityUrl/CallBackUrl/WebAppClient at those https hostnames.
//      e. Raise nginx large-client-header-buffers (chunked .AspNetCore.Cookies auth cookie).
//    The hostnames depend on the post-provision ingress IP, so they can't be static literals
//    in this model today - that dynamic-URL + TLS wiring is the outstanding Radius gap.
// -----------------------------------------------------------------------------
