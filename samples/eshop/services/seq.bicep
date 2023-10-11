import radius as rad

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Name of the SEQ Http Route')
param seqHttpName string

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
          provides: seqHttp.id
        }
      }
    }
  }
}

// NETWORKING ---------------------------------------------------------------

resource seqHttp 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: seqHttpName
}
