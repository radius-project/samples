extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('Git source for the search API image. Override this when validating an unmerged samples branch.')
param source string = 'git::https://github.com/radius-project/samples.git//samples/azure-search-api/src?ref=edge'

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'search-azure-app-test'
  properties: {
    environment: environment
  }
}

resource searchService 'Radius.AI/search@2025-08-01-preview' = {
  name: 'search'
  properties: {
    environment: environment
    application: app.id
  }
}

resource searchApiImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'search-api-image'
  properties: {
    environment: environment
    application: app.id
    tag: 'v1'
    build: {
      source: source
    }
  }
}

resource searchapictr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'searchapictr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      searchapi: {
        image: searchApiImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
        env: {
          CONNECTION_SEARCH_APIKEY: {
            valueFrom: {
              secretKeyRef: {
                secretName: searchService.properties.secrets.name
                key: 'apiKey'
              }
            }
          }
        }
      }
    }
    connections: {
      search: {
        source: searchService.id
      }
    }
  }
}
