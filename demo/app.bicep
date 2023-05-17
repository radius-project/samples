import radius as radius

param application string
param environment string

resource demo 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'demo'
  properties: {
    application: application
    container: {
      image: 'radius.azurecr.io/tutorial/webapp:edge'
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
    connections: {
      redis: {
        source: db.id
      }
    }
  }
}

resource db 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'db'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'redis-kubernetes'
    }
  }
}
