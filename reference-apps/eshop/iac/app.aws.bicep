import radius as radius
import aws as aws

// Parameters --------------------------------------------
param environment string

param ORCHESTRATOR_TYPE string = 'K8S'
param APPLICATION_INSIGHTS_KEY string = ''
param AZURESTORAGEENABLED string = 'False'
param AZURESERVICEBUSENABLED string = 'False'
param ENABLEDEVSPACES string = 'False'
param TAG string = 'linux-dev'

var PICBASEURL = '${gateway.properties.url}/webshoppingapigw/c/api/v1/catalog/items/[0]/pic'

param adminLogin string = 'SA'
@secure()
param adminPassword string

resource eshop 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'eshop'
  location: 'global'
  properties: {
    environment: environment
  }
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'gateway'
  location: 'global'
  properties: {
    application: eshop.id
    routes: [
      {
        path: '/identity-api'
        destination: identityHttp.id
      }
      {
        path: '/ordering-api'
        destination: orderingHttp.id
      }
      {
        path: '/basket-api'
        destination: basketHttp.id
      }
      {
        path: '/webhooks-api'
        destination: webhooksHttp.id
      }
      {
        path: '/webshoppingagg'
        destination: webshoppingaggHttp.id
      }
      {
        path: '/webshoppingapigw'
        destination: webshoppingapigwHttp.id
      }
      {
        path: '/webhooks-web'
        destination: webhooksclientHttp.id
      }
      {
        path: '/webstatus'
        destination: webstatusHttp.id
      }
      {
        path: '/'
        destination: webspaHttp.id
      }
      {
        path: '/webmvc'
        destination: webmvcHttp.id
      }
    ]
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/catalog-api
resource catalog 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'catalog-api'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/catalog.api:${TAG}'
      env: {
        UseCustomizationData: 'False'
        PATH_BASE: '/catalog-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        OrchestratorType: ORCHESTRATOR_TYPE
        PORT: '80'
        GRPC_PORT: '81'
        PicBaseUrl: PICBASEURL
        AzureStorageEnabled: AZURESTORAGEENABLED
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: 'Server=tcp:${sqlCatalogDb.properties.server},1433;Initial Catalog=${sqlCatalogDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=False'
        EventBusConnection: rabbitmq.connectionString()
      }
      ports: {
        http: {
          containerPort: 80
          provides: catalogHttp.id
        }
        grpc: {
          containerPort: 81
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5101
  }
}

resource catalogGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'catalog-grpc'
  location: 'global'
  properties: {
    application: eshop.id
    port: 9101
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/identity-api
resource identity 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'identity-api'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/identity.api:${TAG}'
      env: {
        PATH_BASE: '/identity-api'
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        DPConnectionString: redisKeystore.connectionString()
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        XamarinCallback: ''
        EnableDevspaces: ENABLEDEVSPACES
        ConnectionString: 'Server=tcp:${sqlIdentityDb.properties.server},1433;Initial Catalog=${sqlIdentityDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=False'
        MvcClient: '${gateway.properties.url}/${webmvcHttp.properties.hostname}'
        SpaClient: gateway.properties.url
        BasketApiClient: '${gateway.properties.url}/${basketHttp.properties.hostname}'
        OrderingApiClient: '${gateway.properties.url}/${orderingHttp.properties.hostname}'
        WebShoppingAggClient: '${gateway.properties.url}/${webshoppingaggHttp.properties.hostname}'
        WebhooksApiClient: '${gateway.properties.url}/${webhooksHttp.properties.hostname}'
        WebhooksWebClient: '${gateway.properties.url}/${webhooksclientHttp.properties.hostname}'
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5105
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-api
resource ordering 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-api'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/ordering.api:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        AzureServiceBusEnabled: 'True'
        CheckUpdateTime: '30000'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: ORCHESTRATOR_TYPE
        UseLoadTest: 'False'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        'Serilog__MinimumLevel__Override__ordering-api': 'Verbose'
        PATH_BASE: '/ordering-api'
        GRPC_PORT: '81'
        PORT: '80'
        ConnectionString: 'Server=tcp:${sqlOrderingDb.properties.server},1433;Initial Catalog=${sqlOrderingDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=False'
        EventBusConnection: rabbitmq.connectionString()
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
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
      identity: {
        source: identityHttp.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
    }
  }
}

resource orderingHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'ordering-http'
  location: 'global'
  properties: {
    application: eshop.id
    port: 5102
  }
}

resource orderingGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'ordering-grpc'
  location: 'global'
  properties: {
    application: eshop.id
    port: 9102
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/basket-api
resource basket 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'basket-api'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'radius.azurecr.io/eshop-basket:linux-latest'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        PATH_BASE: '/basket-api'
        OrchestratorType: ORCHESTRATOR_TYPE
        PORT: '80'
        GRPC_PORT: '81'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: redisBasket.connectionString()
        EventBusConnection: rabbitmq.connectionString()
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
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
      identity: {
        source: identityHttp.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
    }
  }
}

resource basketHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'basket-http'
  location: 'global'
  properties: {
    application: eshop.id
    port: 5103
  }
}

resource basketGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'basket-grpc'
  location: 'global'
  properties: {
    application: eshop.id
    port: 9103
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-api
resource webhooks 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webhooks-api'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webhooks.api:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: ORCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: 'Server=tcp:${sqlWebhooksDb.properties.server},1433;Initial Catalog=${sqlWebhooksDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=False'
        EventBusConnection: rabbitmq.connectionString()
        identityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
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
      identity: {
        source: identityHttp.id
      }
      rabbitmq: {
        source: rabbitmq.id
      }
    }
  }
}

resource webhooksHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webhooks-http'
  location: 'global'
  properties: {
    application: eshop.id
    port: 5113
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/payment-api
resource payment 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'payment-api'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/payment.api:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        'Serilog__MinimumLevel__Override__payment-api.IntegrationEvents.EventHandling': 'Verbose'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        OrchestratorType: ORCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: rabbitmq.connectionString()
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5108
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-backgroundtasks
resource orderbgtasks 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-backgroundtasks'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/ordering.backgroundtasks:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/ordering-backgroundtasks'
        UseCustomizationData: 'False'
        CheckUpdateTime: '30000'
        GracePeriodTime: '1'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        'Serilog__MinimumLevel__Override__Microsoft.eShopOnContainers.BuildingBlocks.EventBusRabbitMQ': 'Verbose'
        OrchestratorType: ORCHESTRATOR_TYPE
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        ConnectionString: 'Server=tcp:${sqlOrderingDb.properties.server},1433;Initial Catalog=${sqlOrderingDb.properties.database};User Id=${adminLogin};Password=${adminPassword};Encrypt=False'
        EventBusConnection: rabbitmq.connectionString()
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5111
  }
}

// Other ---------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webshoppingagg
resource webshoppingagg 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshoppingagg'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webshoppingagg:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        PATH_BASE: '/webshoppingagg'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        OrchestratorType: ORCHESTRATOR_TYPE
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
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
      }
      ports: {
        http: {
          containerPort: 80
          provides: webshoppingaggHttp.id
        }
      }
    }
    connections: {
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5121
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/apigwws
resource webshoppingapigw 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'radius.azurecr.io/eshop-envoy:0.1.4'
      env: {}
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5202
  }
}

resource webshoppingapigwHttp2 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw-http-2'
  location: 'global'
  properties: {
    application: eshop.id
    port: 15202
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/ordering-signalrhub
resource orderingsignalrhub 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'ordering-signalrhub'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/ordering.signalrhub:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/ordering-signalrhub'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        AzureServiceBusEnabled: AZURESERVICEBUSENABLED
        EventBusConnection: rabbitmq.connectionString()
        SignalrStoreConnectionString: redisKeystore.connectionString()
        IdentityUrl: identityHttp.properties.url
        IdentityUrlExternal: '${gateway.properties.url}/${identityHttp.properties.hostname}'
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
      rabbitmq: {
        source: rabbitmq.id
      }
    }
  }
}

resource orderingsignalrhubHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'orderingsignalrhub-http'
  location: 'global'
  properties: {
    application: eshop.id
    port: 5112
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-web
resource webhooksclient 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webhooks-client'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webhooks.client:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Production'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webhooks-web'
        Token: 'WebHooks-Demo-Web'
        CallBackUrl: '${gateway.properties.url}/${webhooksclientHttp.properties.hostname}'
        SelfUrl: webhooksclientHttp.properties.url
        WebhooksUrl: webhooksHttp.properties.url
        IdentityUrl: '${gateway.properties.url}/${identityHttp.properties.hostname}'
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5114
  }
}

// Sites ----------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webstatus
resource webstatus 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webstatus'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webstatus:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webstatus'
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
        OrchestratorType: ORCHESTRATOR_TYPE
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 8107
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webspa
resource webspa 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'web-spa'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webspa:${TAG}'
      env: {
        PATH_BASE: '/'
        ASPNETCORE_ENVIRONMENT: 'Production'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        UseCustomizationData: 'False'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        CallBackUrl: '${gateway.properties.url}/'
        DPConnectionString: redisKeystore.connectionString()
        IdentityUrl: '${gateway.properties.url}/identity-api'
        IdentityUrlHC: '${identityHttp.properties.url}/hc'
        PurchaseUrl: '${gateway.properties.url}/webshoppingapigw'
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5104
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webmvc
resource webmvc 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'webmvc'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'eshop/webmvc:${TAG}'
      env: {
        ASPNETCORE_ENVIRONMENT: 'Development'
        ASPNETCORE_URLS: 'http://0.0.0.0:80'
        PATH_BASE: '/webmvc'
        UseCustomizationData: 'False'
        ApplicationInsights__InstrumentationKey: APPLICATION_INSIGHTS_KEY
        UseLoadTest: 'False'
        DPConnectionString: redisKeystore.connectionString()
        OrchestratorType: ORCHESTRATOR_TYPE
        IsClusterEnv: 'True'
        ExternalPurchaseUrl: '${gateway.properties.url}/${webshoppingapigwHttp.properties.hostname}'
        CallBackUrl: '${gateway.properties.url}/webmvc'
        IdentityUrl: '${gateway.properties.url}/identity-api'
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5100
  }
}

// Logging --------------------------------------------

resource seq 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'seq'
  location: 'global'
  properties: {
    application: eshop.id
    container: {
      image: 'datalust/seq:latest'
      env: {
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5340
  }
}

// Infrastructure --------------------------------------

param eksClusterName string
resource eksCluster 'AWS.EKS/Cluster@default' existing = {
  alias: eksClusterName
  properties: {
    Name: eksClusterName
  }
}

param sqlSubnetGroupName string = 'eshopsqlsg${uniqueString(newGuid())}'
resource sqlSubnetGroup 'AWS.RDS/DBSubnetGroup@default' = {
  alias: sqlSubnetGroupName
  properties: {
    DBSubnetGroupName: sqlSubnetGroupName
    DBSubnetGroupDescription: sqlSubnetGroupName
    SubnetIds: eksCluster.properties.ResourcesVpcConfig.SubnetIds
  }
}

param identityDbIdentifier string = 'eshopidentitysql${uniqueString(newGuid())}'
resource identityDb 'AWS.RDS/DBInstance@default' = {
  alias: identityDbIdentifier
  properties: {
    DBInstanceIdentifier: identityDbIdentifier
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    Port: '1433'
    DBSubnetGroupName: sqlSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

param catalogDbIdentifier string = 'eshopcatalogsql${uniqueString(newGuid())}'
resource catalogDb 'AWS.RDS/DBInstance@default' = {
  alias: catalogDbIdentifier
  properties: {
    DBInstanceIdentifier: catalogDbIdentifier
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    Port: '1433'
    DBSubnetGroupName: sqlSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

param orderingDbIdentifier string = 'eshoporderingsql${uniqueString(newGuid())}'
resource orderingDb 'AWS.RDS/DBInstance@default' = {
  alias: orderingDbIdentifier
  properties: {
    DBInstanceIdentifier: orderingDbIdentifier
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    Port: '1433'
    DBSubnetGroupName: sqlSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

param webhooksDbIdentifier string = 'eshopwebhookssql${uniqueString(newGuid())}'
resource webhooksDb 'AWS.RDS/DBInstance@default' = {
  alias: webhooksDbIdentifier
  properties: {
    DBInstanceIdentifier: webhooksDbIdentifier
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    Port: '1433'
    DBSubnetGroupName: sqlSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

param redisSubnetGroupName string = 'eshopredissg${uniqueString(newGuid())}'
resource redisSubnetGroup 'AWS.MemoryDB/SubnetGroup@default' = {
  alias: redisSubnetGroupName
  properties: {
    SubnetGroupName: redisSubnetGroupName
    SubnetIds: eksCluster.properties.ResourcesVpcConfig.SubnetIds
  }
}

param keystoreCacheName string = 'eshopkeystore${uniqueString(newGuid())}'
resource keystoreCache 'AWS.MemoryDB/Cluster@default' = {
  alias: keystoreCacheName
  properties: {
    ClusterName: keystoreCacheName
    NodeType: 'db.t4g.small'
    ACLName: 'open-access'
    SecurityGroupIds: [eksCluster.properties.ClusterSecurityGroupId]
    SubnetGroupName: redisSubnetGroup.properties.SubnetGroupName
    NumReplicasPerShard: 0
  }
}

param basketCacheName string = 'eshopbasket${uniqueString(newGuid())}'
resource basketCache 'AWS.MemoryDB/Cluster@default' = {
  alias: basketCacheName
  properties: {
    ClusterName: basketCacheName
    NodeType: 'db.t4g.small'
    ACLName: 'open-access'
    SecurityGroupIds: [eksCluster.properties.ClusterSecurityGroupId]
    SubnetGroupName: redisSubnetGroup.name
    NumReplicasPerShard: 0
  }
}

// Links ----------------------------------------------------------------------------

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  location: 'global'
  properties: {
    application: eshop.id
    environment: environment
    mode: 'values'
    database: 'IdentityDb'
    server: identityDb.properties.Endpoint.Address
  }
}

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  location: 'global'
  properties: {
    application: eshop.id
    environment: environment
    mode: 'values'
    database: 'CatalogDb'
    server: catalogDb.properties.Endpoint.Address
  }
}

resource sqlOrderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  location: 'global'
  properties: {
    application: eshop.id
    environment: environment
    mode: 'values'
    database: 'OrderingDb'
    server: orderingDb.properties.Endpoint.Address
  }
}

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  location: 'global'
  properties: {
    application: eshop.id
    environment: environment
    mode: 'values'
    database: 'WebhooksDb'
    server: webhooksDb.properties.Endpoint.Address
  }
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'keystore-data'
  location: 'global'
  properties: {
    application: eshop.id
    environment: environment
    mode: 'values'
    host: keystoreCache.properties.ClusterEndpoint.Address
    port: keystoreCache.properties.ClusterEndpoint.Port
    secrets: {
      connectionString: '${keystoreCache.properties.ClusterEndpoint.Address}:${keystoreCache.properties.ClusterEndpoint.Port},ssl=true'
    }
  }
}

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  location: 'global'
  properties: {
    application: eshop.id
    environment: environment
    mode: 'values'
    host: basketCache.properties.ClusterEndpoint.Address
    port: basketCache.properties.ClusterEndpoint.Port
    secrets: {
      connectionString: '${basketCache.properties.ClusterEndpoint.Address}:${basketCache.properties.ClusterEndpoint.Port},ssl=true'
    }
  }
}

// TEMP: Using containerized rabbitMQ instead of AWS SNS until AWS nonidempotency is resolved
resource rabbitmqContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'rabbitmq-container-eshop-event-bus'
  location: 'global'
  properties: {
    application: eshop.id
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
  location: 'global'
  properties: {
    application: eshop.id
    port: 5672
  }
}

resource rabbitmq 'Applications.Link/rabbitmqMessageQueues@2022-03-15-privatepreview' = {
  name: 'eshop-event-bus'
  location: 'global'
  properties: {
    application: eshop.id
    environment: environment
    mode: 'values'
    queue: 'eshop-event-bus'
    secrets: {
      connectionString: rabbitmqRoute.properties.hostname
    }
  }
}
