extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

param buildSource string = 'git::https://github.com/mongo-express/mongo-express.git?ref=486c162ec8bdbc8b8c1c61b36b53dee71fdf7034'

@secure()
param ME_CONFIG_SITE_COOKIESECRET string

@secure()
param ME_CONFIG_SITE_SESSIONSECRET string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'mongo-express'
  properties: {
    environment: environment
  }
}

resource mongo 'Radius.Data/mongoDatabases@2025-08-01-preview' = {
  name: 'mongo'
  properties: {
    environment: environment
    application: app.id
    database: 'mongo_db'
  }
}

resource image 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'image'
  properties: {
    environment: environment
    application: app.id
    build: {
      source: buildSource
      platforms: ['linux/amd64']
    }
  }
}

resource web 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'web'
  properties: {
    environment: environment
    application: app.id
    containers: {
      mongoexpress: {
        image: image.properties.imageReference
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
          ME_CONFIG_MONGODB_ENABLE_ADMIN: {
            value: 'true'
          }
          ME_CONFIG_BASICAUTH: {
            value: 'false'
          }
          ME_CONFIG_SITE_COOKIESECRET: {
            value: ME_CONFIG_SITE_COOKIESECRET
          }
          ME_CONFIG_SITE_SESSIONSECRET: {
            value: ME_CONFIG_SITE_SESSIONSECRET
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/status'
            port: 8081
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
