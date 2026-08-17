extension radius

@description('The Radius Environment ID. Injected automatically by the rad CLI.')
param environment string

@description('Container image for the demo app. Defaults to the published sample image; overridden in CI to test a locally-built image.')
param image string = 'ghcr.io/radius-project/samples/demo:latest'

// Environment name derived from the Environment ID, used to keep resource names
// unique per environment (e.g. dev/test/prod) within the same resource group.
var environmentName = last(split(environment, '/'))

resource demoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'demo-${environmentName}'
  properties: {
    environment: environment
  }
}

resource demoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'demo-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    containers: {
      web: {
        image: image
        ports: {
          web: {
            containerPort: 3000
          }
        }
      }
    }
  }
}
