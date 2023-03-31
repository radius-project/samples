import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius region to deploy resources into. Only global is supported today')
@allowed([
  'global'
])
param ucpLocation string

@description('Radius application ID')
param application string

// CONTAINERS ------------------------------------------------------------

resource seq 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'seq'
  location: ucpLocation
  properties: {
    application: application
    container: {
      image: 'datalust/seq:latest'
      env: {
        ACCEPT_EULA: 'Y'
      }
      ports: {
        web: {
          containerPort: 80
          port: 5340
        }
      }
    }
  }
}

