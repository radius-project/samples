import radius as radius

@description('The Radius Application ID.')
param appId string

@description('The name of the Seq HTTP route.')
param seqRouteName string

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

//-----------------------------------------------------------------------------
// Deploy Seq container
//-----------------------------------------------------------------------------

resource seq 'Applications.Core/containers@2022-03-15-privatepreview' = {
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
