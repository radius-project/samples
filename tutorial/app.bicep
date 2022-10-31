import radius as radius

param environment string

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'webapp'
  location: 'global'
  properties: {
    environment: environment
  }
}

resource frontend 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'frontend'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/tutorial/webapp:edge'
      ports: {
        web: {
          containerPort: 3000
          provides: frontendRoute.id
        }
      }
    }
    connections: {
      itemstore: {
        source: db.id
      }
    }
  }
}

resource frontendRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' = {
  name: 'http-route'
  location: 'global'
  properties: {
    application: app.id
  }
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'public'
  location: 'global'
  properties: {
    application: app.id
    routes: [
      {
        path: '/'
        destination: frontendRoute.id
      }
    ]
  }
}

resource db 'Applications.Link/mongoDatabases@2022-03-15-privatepreview' = {
  name: 'db'
  location: 'global'
  properties: {
    environment: app.properties.environment
    application: app.id
    secrets: {
      connectionString: 'mongodb://${mongo.outputs.name}:${mongo.outputs.port}/${mongo.outputs.dbName}?authSource=admin'
    }
  }
}

module mongo 'mongo-container.bicep' = {
  name: 'mongo-module'
}
