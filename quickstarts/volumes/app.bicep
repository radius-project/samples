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
      image: 'radius.azurecr.io/quickstarts/volumes:edge'
      volumes: {
        temp: {
          kind: 'ephemeral'
          managedStore: 'memory'
          mountPath: '/tmpdir'
        }
      }
    }
  }
}
