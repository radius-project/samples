extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('The Radius resource name. The workflow passes the same globally-unique value used for the Cosmos DB account so verification can use one name for both Radius and Azure.')
param accountName string

var databaseName = 'mongo_db'

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'mongodb-azure-app-test'
  properties: {
    environment: environment
  }
}

resource mongo 'Radius.Data/mongoDatabases@2025-08-01-preview' = {
  name: accountName
  properties: {
    environment: environment
    application: app.id
    database: databaseName
  }
}

resource mongoExpressImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'mongo-express-image'
  properties: {
    environment: environment
    application: app.id

    tag: 'v1.0.2'
    build: {
      source: 'git::https://github.com/mongo-express/mongo-express.git//?ref=v1.0.2'
    }
  }
}

resource mectr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'mectr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      mongoexpress: {
        image: mongoExpressImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8081
          }
        }
        env: {
          ME_CONFIG_MONGODB_URL: {
            valueFrom: {
              secretKeyRef: {
                secretName: mongo.properties.secrets.name
                key: 'connectionString'
              }
            }
          }

          ME_CONFIG_MONGODB_SSL: {
            value: 'true'
          }

          ME_CONFIG_BASICAUTH: {
            value: 'false'
          }

          ME_CONFIG_MONGODB_ENABLE_ADMIN: {
            value: 'true'
          }
        }
      }
    }

    connections: {
      mongo: {
        source: mongo.id
      }
    }
  }
}
