import radius as rad

param radEnvironment string

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'myapp'
  location: 'global'
  properties: {
    environment: radEnvironment
  }
}

resource container 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'mycontainer'
  location: 'global'
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
        source: mongoConnector.id
      }
    }
  }
}

module mongoContainerModule 'br:radius.azurecr.io/modules/mongo-container:edge' = {
  name: 'mongo-container-module'
}

resource mongoConnector 'Applications.Connector/mongoDatabases@2022-03-15-privatepreview' = {
  name: 'mongo-connector'
  location: 'global'
  properties: {
    environment: radEnvironment
    application: app.id
    secrets: {
      connectionString: mongoContainerModule.outputs.connectionString
    }
  }
}
