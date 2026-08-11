extension radius

param environment string

param buildSource string = 'git::https://github.com/radius-project/samples.git//samples/azure-search-api/src?ref=f10b1a2b891157967b51a9e9b4aedbc40c9271c5'

resource azureSearchApiApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'azure-search-api'
  properties: {
    environment: environment
  }
}

resource search 'Radius.AI/search@2025-08-01-preview' = {
  name: 'search'
  properties: {
    environment: environment
    application: azureSearchApiApp.id
  }
}

resource azureSearchApiImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'azure-search-api-image'
  properties: {
    environment: environment
    application: azureSearchApiApp.id
    tag: 'f10b1a2b8911'
    build: {
      source: buildSource
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource azureSearchApiContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'azure-search-api'
  properties: {
    environment: environment
    application: azureSearchApiApp.id
    containers: {
      'azure-search-api': {
        image: azureSearchApiImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
        env: {
          CONNECTION_SEARCH_APIKEY: {
            valueFrom: {
              secretKeyRef: {
                secretName: search.properties.secrets.name
                key: 'apiKey'
              }
            }
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/healthz'
            port: 8080
          }
        }
      }
    }
    connections: {
      search: {
        source: search.id
      }
    }
  }
}
