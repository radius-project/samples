import radius as radius

// Parameters --------------------------------------------
param environmentId string

param location string = resourceGroup().location

param mongoUsername string = 'admin'

param mongoPassword string = newGuid()
param ESHOP_EXTERNAL_DNS_NAME_OR_IP string = '*'
param CLUSTER_IP string
param OCHESTRATOR_TYPE string = 'K8S'
param APPLICATION_INSIGHTS_KEY string = ''
param AZURESTORAGEENABLED string = 'False'
param AZURESERVICEBUSENABLED string = 'False'
param ENABLEDEVSPACES string = 'False'
param TAG string = 'linux-dev'

var CLUSTERDNS = 'http://${CLUSTER_IP}.nip.io'
var PICBASEURL = '${CLUSTERDNS}/webshoppingapigw/c/api/v1/catalog/items/[0]/pic'

var tempRabbitmqConnectionString = 'eshop-starter-rabbitmq-route-${uniqueString('eshop_event_bus')}'

param adminLogin string = 'SA'
@secure()
param adminPassword string

resource eshop 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'eshop'
  location: location
  properties: {
    environment: environmentId
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/catalog-api
resource catalog 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'catalog-api'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/catalog.api:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        UseCustomizationData: 'False'
        PATH_BASE: '/catalog-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        OrchestratorType: OCHESTRATOR_TYPE
        PORT: '80'
        GRPC_PORT: '81'
        PicBaseUrl: PICBASEURL
        AzureStorageEnabled: AZURESTORAGEENABLED
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: 'Server=tcp:${sqlCatalogDb.properties.server},1433;Initial Catalog=${sqlCatalogDb.properties.database};User Id=${adminLogin};Password=${adminPassword};'
        EventBusConnection: tempRabbitmqConnectionString
      }
      ports: {
        http: {
          containerPort: 80
          provides: catalogHttp.id
        }
        grpc: {
          containerPort: 81
          provides: catalogGrpc.id
        }
      }
    }
    connections: {
      sql: {
        source: sqlCatalogDb.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
    }
  }
}

resource catalogHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'catalog-http'
  location: location
  properties: {
    application: eshop.id
    port: 5101
  }
}

resource catalogGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'catalog-grpc'
  location: location
  properties: {
    application: eshop.id
    port: 9101
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/identity-api
resource identity 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'identity-api'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/identity.api:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        PATH_BASE: '/identity-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: 'K8S'
        IsClusterEnv: 'True'
        DPConnectionString: redisKeystore.properties.host
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        XamarinCallback: ''
        EnableDevspaces: ENABLEDEVSPACES
        ConnectionString: 'Server=tcp:${sqlIdentityDb.properties.server},1433;Initial Catalog=${sqlIdentityDb.properties.database};User Id=${adminLogin};Password=${adminPassword}'
        MvcClient: '${CLUSTERDNS}${webmvcHttp.properties.gateway.rules.webmvc.path.value}'
        SpaClient: CLUSTERDNS
        BasketApiClient: '${CLUSTERDNS}${basketHttp.properties.gateway.rules.basket.path.value}'
        OrderingApiClient: '${CLUSTERDNS}${orderingHttp.properties.gateway.rules.ordering.path.value}'
        WebShoppingAggClient: '${CLUSTERDNS}${webshoppingaggHttp.properties.gateway.rules.webshoppingagg.path.value}'
        WebhooksApiClient: '${CLUSTERDNS}${webhooksHttp.properties.gateway.rules.webhooks.path.value}'
        WebhooksWebClient: '${CLUSTERDNS}${webhooksclientHttp.properties.gateway.rules.webhooks.path.value}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: identityHttp.id
        }
      }
    }

    connections: {
      redis: {
        source: redisKeystore.id
      }
      sql: {
        source: sqlIdentityDb.id
      }
      webmvc: {
        source: webmvcHttp.id
      }
      webspa: {
        source: webspaHttp.id
      }
      basket: {
        source: basketHttp.id
      }
      ordering: {
        source: orderingHttp.id
      }
      webshoppingagg: {
        source: webshoppingaggHttp.id
      }
      webhooks: {
        source: webhooksHttp.id
      }
      webhoolsclient: {
        source: webhooksclientHttp.id
      }
    }
  }
}

resource identityHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'identity-http'
  location: location
  properties: {
    application: eshop.id
    port: 5105
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        identity: {
          path: {
            value: '/identity-api'
          }
        }
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-api
resource ordering 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-api'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/ordering.api:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        CheckUpdateTime: '30000'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: OCHESTRATOR_TYPE
        UseLoadTest: 'False'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        'Serilog__MinimumLevel__Override__ordering-api': 'Verbose'
        PATH_BASE: '/ordering-api'
        GRPC_PORT: '81'
        PORT: '80'
        ConnectionString: 'Server=tcp:${sqlOrderingDb.properties.server},1433;Initial Catalog=${sqlOrderingDb.properties.database};User Id=${adminLogin};Password=${adminPassword}'
        EventBusConnection: tempRabbitmqConnectionString
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${CLUSTERDNS}${identityHttp.properties.gateway.rules.identity.path.value}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: orderingHttp.id
        }
        grpc: {
          containerPort: 81
          provides: orderingGrpc.id
        }
      }
    }
    connections: {
      sql: {
        source: sqlOrderingDb.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
      identity: {
        source: identityHttp.id
      }
    }
  }
}

resource orderingHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'ordering-http'
  location: location
  properties: {
    application: eshop.id
    port: 5102
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        ordering: {
          path: {
            value: '/ordering-api'
          }
        }
      }
    }
  }
}

resource orderingGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'ordering-grpc'
  location: location
  properties: {
    application: eshop.id
    port: 9102
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/basket-api
resource basket 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'basket-api'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/basket.api:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        PATH_BASE: '/basket-api'
        OrchestratorType: 'K8S'
        PORT: '80'
        GRPC_PORT: '81'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: '${redisBasket.properties.host}:${redisBasket.properties.port}'
        EventBusConnection: tempRabbitmqConnectionString
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${CLUSTERDNS}${identityHttp.properties.gateway.rules.identity.path.value}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: basketHttp.id
        }
        grpc: {
          containerPort: 81
          provides: basketGrpc.id
        }
      }
    }
    connections: {
      redis: {
        source: redisBasket.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
      identity: {
        source: identityHttp.id
      }
    }
  }
}

resource basketHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'basket-http'
  location: location
  properties: {
    application: eshop.id
    port: 5103
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        basket: {
          path: {
            value: '/basket-api'
          }
        }
      }
    }
  }
}

resource basketGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'basket-grpc'
  location: location
  properties: {
    application: eshop.id
    port: 9103
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-api
resource webhooks 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webhooks-api'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webhooks.api:linux-dev'
      env: {
        disableDefaultEnvVars: 'True'
        PATH_BASE: '/webhooks-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: OCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: 'Server=tcp:${sqlWebhooksDb.properties.server},1433;Initial Catalog=${sqlWebhooksDb.properties.database};User Id=${adminLogin};Password=${adminPassword}'
        EventBusConnection: tempRabbitmqConnectionString
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${CLUSTERDNS}${identityHttp.properties.gateway.rules.identity.path.value}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webhooksHttp.id
        }
      }
    }

    connections: {
      sql: {
        source: sqlWebhooksDb.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
      identity: {
        source: identityHttp.id
      }
    }
  }
}

resource webhooksHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webhooks-http'
  location: location
  properties: {
    application: eshop.id
    port: 5113
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        webhooks: {
          path: {
            value: '/webhooks-api'
          }
        }
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/payment-api
resource payment 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'payment-api'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/payment.api:linux-dev'
      env: {
        disableDefaultEnvVars: 'True'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        'Serilog__MinimumLevel__Override__payment-api.IntegrationEvents.EventHandling': 'Verbose'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        OrchestratorType: OCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: tempRabbitmqConnectionString
      }
      ports: {
        http: {
          containerPort: 80
          provides: paymentHttp.id
        }
      }
    }
    connections: {
      rabbitmq: {
        source: rabbitmq.id
      }
    }
  }
}

resource paymentHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'payment-http'
  location: location
  properties: {
    application: eshop.id
    port: 5108
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-backgroundtasks
resource orderbgtasks 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-backgroundtasks'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/ordering.backgroundtasks:linux-dev'
      env: {
        disableDefaultEnvVars: 'True'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        CheckUpdateTime: '30000'
        GracePeriodTime: '1'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        OrchestratorType: OCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: 'Server=tcp:${sqlOrderingDb.properties.server},1433;Initial Catalog=${sqlOrderingDb.properties.database};User Id=${adminLogin};Password=${adminPassword}'
        EventBusConnection: tempRabbitmqConnectionString
      }
      ports: {
        http: {
          containerPort: 80
          provides: orderbgtasksHttp.id
        }
      }
    }
    connections: {
      sql: {
        source: sqlOrderingDb.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
    }
  }
}

resource orderbgtasksHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'orderbgtasks-http'
  location: location
  properties: {
    application: eshop.id
    port: 5111
  }
}

// Other ---------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webshoppingagg
resource webshoppingagg 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshoppingagg'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webshoppingagg:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        ASPNETCORE_ENVIRONMENT: 'Development'
        PATH_BASE: '/webshoppingagg'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: OCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        urls__basket: basketHttp.properties.url
        urls__catalog: catalogHttp.properties.url
        urls__orders: orderingHttp.properties.url
        urls__identity: identityHttp.properties.url
        urls__grpcBasket: basketGrpc.properties.url
        urls__grpcCatalog: catalogGrpc.properties.url
        urls__grpcOrdering: orderingGrpc.properties.url
        CatalogUrlHC: '${catalogHttp.properties.url}/hc'
        OrderingUrlHC: '${orderingHttp.properties.url}/hc'
        IdentityUrlHC: '${identityHttp.properties.url}/hc'
        BasketUrlHC: '${basketHttp.properties.url}/hc'
        PaymentUrlHC: '${paymentHttp.properties.url}/hc'
        IdentityUrlExternal: '${CLUSTERDNS}${identityHttp.properties.gateway.rules.identity.path.value}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webshoppingaggHttp.id
        }
      }
    }
    connections: {
      rabbitmq: {
        source: rabbitmq.id
      }
      identity: {
        source: identityHttp.id
      }
      ordering: {
        source: orderingHttp.id
      }
      catalog: {
        source: catalogHttp.id
      }
      basket: {
        source: basketHttp.id
      }
    }
  }
}

resource webshoppingaggHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshoppingagg-http'
  location: location
  properties: {
    application: eshop.id
    port: 5121
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        webshoppingagg: {
          path: {
            value: '/webshoppingagg'
          }
        }
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/apigwws
resource webshoppingapigw 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'radius.azurecr.io/eshop-envoy:0.1.3'
      env: {
        disableDefaultEnvVars: 'True'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webshoppingapigwHttp.id
        }
        http2: {
          containerPort: 8001
          provides: webshoppingapigwHttp2.id
        }
      }
    }
    connections: {}
  }
}

resource webshoppingapigwHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw-http'
  location: location
  properties: {
    application: eshop.id
    port: 5202
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        webshoppingapigw: {
          path: {
            value: '/webshoppingapigw'
          }
        }
      }
    }
  }
}

resource webshoppingapigwHttp2 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw-http-2'
  location: location
  properties: {
    application: eshop.id
    port: 15202
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-signalrhub
resource orderingsignalrhub 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-signalrhub'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/ordering.signalrhub:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        PATH_BASE: '/payment-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: OCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: tempRabbitmqConnectionString
        SignalrStoreConnectionString: '${redisKeystore.properties.host}'
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${CLUSTERDNS}${identityHttp.properties.gateway.rules.identity.path.value}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: orderingsignalrhubHttp.id
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
      identity: {
        source: identityHttp.id
      }
      ordering: {
        source: orderingHttp.id
      }
      catalog: {
        source: catalogHttp.id
      }
      basket: {
        source: basketHttp.id
      }
    }
  }
}

resource orderingsignalrhubHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'orderingsignalrhub-http'
  location: location
  properties: {
    application: eshop.id
    port: 5112
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-web
resource webhooksclient 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webhooks-client'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webhooks.client:linux-dev'
      env: {
        disableDefaultEnvVars: 'True'
        ASPNETCORE_ENVIRONMENT: 'Production'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webhooks-web'
        Token: 'WebHooks-Demo-Web'
        CallBackUrl: '${CLUSTERDNS}${webhooksclientHttp.properties.gateway.rules.webhooks.path.value}'
        SelfUrl: webhooksclientHttp.properties.url
        WebhooksUrl: webhooksHttp.properties.url
        IdentityUrl: '${CLUSTERDNS}${identityHttp.properties.gateway.rules.identity.path.value}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webhooksclientHttp.id
        }
      }
    }
    connections: {
      webhooks: {
        source: webhooksHttp.id
      }
      identity: {
        source: identityHttp.id
      }
    }
  }
}

resource webhooksclientHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webhooksclient-http'
  location: location
  properties: {
    application: eshop.id
    port: 5114
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        webhooks: {
          path: {
            value: '/webhooks-web'
          }
        }
      }
    }
  }
}

// Sites ----------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webstatus
resource webstatus 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webstatus'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webstatus:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        HealthChecksUI__HealthChecks__0__Name: 'WebMVC HTTP Check'
        HealthChecksUI__HealthChecks__0__Uri: '${webmvcHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__1__Name: 'WebSPA HTTP Check'
        HealthChecksUI__HealthChecks__1__Uri: '${webspaHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__2__Name: 'Web Shopping Aggregator GW HTTP Check'
        HealthChecksUI__HealthChecks__2__Uri: '${webshoppingaggHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__4__Name: 'Ordering HTTP Check'
        HealthChecksUI__HealthChecks__4__Uri: '${orderingHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__5__Name: 'Basket HTTP Check'
        HealthChecksUI__HealthChecks__5__Uri: '${basketHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__6__Name: 'Catalog HTTP Check'
        HealthChecksUI__HealthChecks__6__Uri: '${catalogHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__7__Name: 'Identity HTTP Check'
        HealthChecksUI__HealthChecks__7__Uri: '${identityHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__8__Name: 'Payments HTTP Check'
        HealthChecksUI__HealthChecks__8__Uri: '${paymentHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__9__Name: 'Ordering SignalRHub HTTP Check'
        HealthChecksUI__HealthChecks__9__Uri: '${orderingsignalrhubHttp.properties.url}/hc'
        HealthChecksUI__HealthChecks__10__Name: 'Ordering HTTP Background Check'
        HealthChecksUI__HealthChecks__10__Uri: '${orderbgtasksHttp.properties.url}/hc'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: OCHESTRATOR_TYPE
      }
      ports: {
        http: {
          containerPort: 80
          provides: webstatusHttp.id
        }
      }
    }
    connections: {}
  }
}

resource webstatusHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webstatus-http'
  location: location
  properties: {
    application: eshop.id
    port: 8107
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        webstatus: {
          path: {
            value: '/webstatus'
          }
        }
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webspa
resource webspa 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'web-spa'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webspa:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        PATH_BASE: '/'
        ASPNETCORE_ENVIRONMENT: 'Production'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: OCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        CallBackUrl: '${CLUSTERDNS}/'
        DPConnectionString: '${redisKeystore.properties.host}'
        IdentityUrl: '${CLUSTERDNS}${identityHttp.properties.gateway.rules.identity.path.value}'
        IdentityUrlHC: '${identityHttp.properties.url}/hc'
        PurchaseUrl: '${CLUSTERDNS}${webshoppingapigwHttp.properties.gateway.rules.webshoppingapigw.path.value}'
        SignalrHubUrl: orderingsignalrhubHttp.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: webspaHttp.id
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
      }
      webshoppingagg: {
        source: webshoppingaggHttp.id
      }
      identity: {
        source: identityHttp.id
      }
      webshoppingapigw: {
        source: webshoppingapigwHttp.id
      }
      orderingsignalrhub: {
        source: orderingsignalrhubHttp.id
      }
    }
  }
}

resource webspaHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webspa-http'
  location: location
  properties: {
    application: eshop.id
    port: 5104
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        webspa: {
          path: {
            value: '/'
          }
        }
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webmvc
resource webmvc 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webmvc'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webmvc:${TAG}'
      env: {
        disableDefaultEnvVars: 'True'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webmvc'
        UseCustomizationData: 'False'
        DPConnectionString: redisKeystore.properties.host
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        OrchestratorType: OCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        ExternalPurchaseUrl: '${CLUSTERDNS}${webshoppingapigwHttp.properties.gateway.rules.webshoppingapigw.path.value}'
        CallBackUrl: 'http://${CLUSTER_IP}.nip.io/webmvc'
        IdentityUrl: 'http://${CLUSTER_IP}.nip.io/identity-api'
        IdentityUrlHC: '${identityHttp.properties.url}/hc'
        PurchaseUrl: webshoppingapigwHttp.properties.url
        SignalrHubUrl: orderingsignalrhubHttp.properties.url
      }
      ports: {
        http: {
          containerPort: 80
          provides: webmvcHttp.id
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
      }
      webshoppingagg: {
        source: webshoppingaggHttp.id
      }
      identity: {
        source: identityHttp.id
      }
      webshoppingapigw: {
        source: webshoppingapigwHttp.id
      }
      orderingsignalrhub: {
        source: orderingsignalrhubHttp.id
      }
    }
  }
}

resource webmvcHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webmvc-http'
  location: location
  properties: {
    application: eshop.id
    port: 5100
    gateway: {
      source: gateway.id
      hostname: ESHOP_EXTERNAL_DNS_NAME_OR_IP
      rules: {
        webmvc: {
          path: {
            value: '/webmvc'
          }
        }
      }
    }
  }
}

// Logging --------------------------------------------

resource seq 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'seq'
  location: location
  properties: {
    application: eshop.id
    container: {
      image: 'datalust/seq:latest'
      env: {
        disableDefaultEnvVars: 'True'
        ACCEPT_EULA: 'Y'
      }
      ports: {
        web: {
          containerPort: 80
          provides: seqHttp.id
        }
      }
    }
    connections: {}
  }
}

resource seqHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'seq-http'
  location: location
  properties: {
    application: eshop.id
    port: 5340
  }
}

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
        disableDefaultEnvVars: 'True'
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
        disableDefaultEnvVars: 'True'
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
        disableDefaultEnvVars: 'True'
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
        disableDefaultEnvVars: 'True'
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
        disableDefaultEnvVars: 'True'
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
      env: {
        disableDefaultEnvVars: 'True'
      }
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
      env: {
        disableDefaultEnvVars: 'True'
      }
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
        disableDefaultEnvVars: 'True'
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
