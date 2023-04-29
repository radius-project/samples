import radius as rad

param environment string

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'myapp'
  properties: {
    environment: environment
  }
}

resource container 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'mycontainer'
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/quickstarts/envvars:edge'
      env: {
        FOO: 'BAR'
        BAZ: app.name
      }
    }
    connections: {
      myconnection: {
        source: mongoLink.id
      }
    }
  }
}

module mongoContainerModule 'br:radius.azurecr.io/modules/mongo-container:edge' = {
  name: 'mongo-container-module'
}

resource mongoLink 'Applications.Link/mongoDatabases@2022-03-15-privatepreview' = {
  name: 'mongo-link'
  properties: {
    environment: environment
    application: app.id
    mode: 'values'
    host: mongoContainerModule.outputs.host
    port: mongoContainerModule.outputs.port
    secrets: {
      connectionString: mongoContainerModule.outputs.connectionString
    }
  }
}
