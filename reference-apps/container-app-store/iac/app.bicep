import radius as radius

param environment string

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'store'
  location: 'global'
  properties: {
    environment: environment
  }
}

resource go_app 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'goapp'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/reference-apps/container-app-go-service:edge'
      ports: {
        web: {
          containerPort: 8050
        }
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'go-app'
        appPort: 8050
        provides: go_app_route.id
      }
    ]
  }
}

resource go_app_route 'Applications.Connector/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'go-app-route'
  location: 'global'
  properties: {
    application: app.id
    environment: environment
    appId: 'go-app'
  }
}

resource node_app_route 'Applications.Core/httpRoutes@2022-03-15-privatepreview' = {
  name: 'node-app-route'
  location: 'global'
  properties: {
    application: app.id
  }
}

resource node_app_gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'node-app-gateway'
  location: 'global'
  properties: {
    application: app.id
    routes: [ 
      {
        path: '/'
        destination: node_app_route.id
      }
  ]
  }
}
resource node_app 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'nodeapp'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/reference-apps/container-app-node-service:edge'
      env: {
        'ORDER_SERVICE_NAME': python_app_route.properties.appId
        'INVENTORY_SERVICE_NAME': go_app_route.properties.appId
      }
      ports: {
        web: {
          containerPort: 3000
          provides: node_app_route.id
        }
      }
    }
    connections: {
      inventory: {
        source: go_app_route.id
      }
      orders: {
        source: python_app_route.id
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'node-app'
      }
    ]
  }
}

resource python_app 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'pythonapp'
  location: 'global'
  properties: {
    application: app.id
    container: {
      image: 'radius.azurecr.io/reference-apps/container-app-python-service:edge'
      ports: {
        web: {
          containerPort: 5000
        }
      }
    }
    connections: {
      kind: {
        source: infraFile.outputs.statestoreID
      }
    }
    extensions: [
      {
        kind: 'daprSidecar'
        appId: 'python-app'
        appPort: 5000
        provides: python_app_route.id
      }
    ]
  }
}

resource python_app_route 'Applications.Connector/daprInvokeHttpRoutes@2022-03-15-privatepreview' = {
  name: 'python-app'
  location: 'global'
  properties: {
    application: app.id
    environment: environment
    appId: 'python-app'
  }
}

module infraFile 'infra-selfhosted.bicep' = {
  name: 'infrastructure'
  params: {
    environment: environment
    applicationId: app.id
  }
}  
