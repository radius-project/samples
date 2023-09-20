import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Seq HTTP route.')
param seqRouteName string

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource seqRoute 'Applications.Core/httpRoutes@2023-10-01-preview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Seq container
//-----------------------------------------------------------------------------

resource seq 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'seq'
  properties: {
    application: appId
    container: {
      image: 'datalust/seq:latest'
      env: {
        ACCEPT_EULA: 'Y'
      }
      ports: {
        http: {
          containerPort: 80
          provides: seqRoute.id
        }
      }
    }
  }
}
