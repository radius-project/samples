extension radius

param environment string

@description('Globally-unique Cosmos DB account name shared with the environment so Radius and Azure use the same value.')
param accountName string

resource mongoExpressApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'mongo-express'
  properties: {
    environment: environment
  }
}

resource mongoDb 'Radius.Data/mongoDatabases@2025-08-01-preview' = {
  name: accountName
  properties: {
    environment: environment
    application: mongoExpressApp.id
    database: 'mongo_db'
  }
}

resource mongoExpressImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'mongo-express-image'
  properties: {
    environment: environment
    application: mongoExpressApp.id
    tag: 'v1.0.2'
    build: {
      source: 'git::https://github.com/mongo-express/mongo-express.git?ref=v1.0.2'
    }
  }
}

resource mongoExpressContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'mongo-express'
  properties: {
    environment: environment
    application: mongoExpressApp.id
    containers: {
      mongoExpress: {
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
                secretName: mongoDb.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
          ME_CONFIG_MONGODB_SSL: {
            value: 'true'
          }
          ME_CONFIG_MONGODB_ENABLE_ADMIN: {
            value: 'true'
          }
          ME_CONFIG_BASICAUTH: {
            value: 'false'
          }
        }
      }
    }
    connections: {
      mongo: {
        source: mongoDb.id
      }
    }
  }
}
