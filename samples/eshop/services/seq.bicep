import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

// CONTAINERS ------------------------------------------------------------

resource seq 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'seq'
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


// Output
@description('Name of the SEQ container')
output container string = seq.name
