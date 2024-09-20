extension radius

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container registry to pull from, with optional path.')
param imageRegistry string

@description('Container image tag to use for eshop images')
param imageTag string

@description('Name of the Gateway')
param gatewayName string

@description('Name of the Keystore Redis portable resource')
param redisKeystoreName string

// CONTAINER --------------------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webspa
resource webspa 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'web-spa'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/webspa:${imageTag}'
      env: {
        PATH_BASE: {
          value: '/'
        }
        ASPNETCORE_ENVIRONMENT: {
          value: 'Production'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        UseCustomizationData: {
          value: 'False'
        }
        ORCHESTRATOR_TYPE: {
          value: 'K8S'
        }
        IsClusterEnv: {
          value: 'True'
        }
        CallBackUrl: {
          value: '${gateway.properties.url}/'
        }
        DPConnectionString: {
          value: redisKeystore.listSecrets().connectionString
        }
        IdentityUrl: {
          value: '${gateway.properties.url}/identity-api'
        }
        IdentityUrlHC: {
          value: 'http://identity-api:5105/liveness'
        }
        PurchaseUrl: {
          value: '${gateway.properties.url}/webshoppingapigw'
        }
        SignalrHubUrl: {
          value: 'http://ordering-signalrhub:5112'
        }
      }
      ports: {
        http: {
          containerPort: 80
          port: 5104
        }
      }
      livenessProbe: {
        kind: 'httpGet'
        path: '/liveness'
        containerPort: 80
      }
      readinessProbe: {
        kind: 'httpGet'
        path: '/hc'
        containerPort: 80
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: 'http://webshoppingagg:5121'
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'http://identity-api:5105'
        disableDefaultEnvVars: true
      }
      webshoppingapigw: {
        source: 'http://webshoppingapigw:5202'
        disableDefaultEnvVars: true
      }
      orderingsignalrhub: {
        source: 'http://ordering-signalrhub:5112'
        disableDefaultEnvVars: true
      }
    }
  }
}

// Based on adfasfhttps://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webmvc
resource webmvc 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webmvc'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/webmvc:${imageTag}'
      env: {
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        PATH_BASE: {
          value: '/webmvc'
        }
        UseCustomizationData: {
          value: 'False'
        }
        DPConnectionString: {
          value: redisKeystore.listSecrets().connectionString
        }
        UseLoadTest: {
          value: 'False'
        }
        ORCHESTRATOR_TYPE: {
          value: 'K8S'
        }
        IsClusterEnv: {
          value: 'True'
        }
        ExternalPurchaseUrl: {
          value: '${gateway.properties.url}/webshoppingapigw'
        }
        CallBackUrl: {
          value: '${gateway.properties.url}/webmvc'
        }
        IdentityUrl: {
          value: '${gateway.properties.url}/identity-api'
        }
        IdentityUrlHC: {
          value: 'http://identity-api:5105/liveness'
        }
        PurchaseUrl: {
          value: 'http://webshoppingapigw:5202'
        }
        SignalrHubUrl: {
          value: 'http://ordering-signalrhub:5112'
        }
      }
      ports: {
        http: {
          containerPort: 80
          port: 5100
        }
      }
    }
    connections: {
      redis: {
        source: redisKeystore.id
        disableDefaultEnvVars: true
      }
      webshoppingagg: {
        source: 'http://webshoppingagg:5121'
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'http://identity-api:5105'
        disableDefaultEnvVars: true
      }
      webshoppingapigw: {
        source: 'http://webshoppingapigw:5202'
        disableDefaultEnvVars: true
      }
      orderingsignalrhub: {
        source: 'http://ordering-signalrhub:5112'
        disableDefaultEnvVars: true
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

// PORTABLE RESOURCES ------------------------------------------------------

resource redisKeystore 'Applications.Datastores/redisCaches@2023-10-01-preview' existing = {
  name: redisKeystoreName
}

// Output
@description('Name of the Web spa container')
output spacontainer string = webspa.name

@description('Name of the Web mvc container')
output mvccontainer string = webmvc.name
