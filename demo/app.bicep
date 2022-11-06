import radius as radius

param environment string

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'demo'
  location: 'global'
  properties: {
    environment: environment
  }
}

resource demo 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'demo'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/tutorial/demo:edge'
      ports: {
        web: {
          containerPort: 3000
        }
      }
      livenessProbe: {
        kind: 'httpGet'
        containerPort: 3000
        path: '/healthz'
      }
    }
  }
}
