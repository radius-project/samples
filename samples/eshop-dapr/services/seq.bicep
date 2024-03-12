import radius as radius

@description('The Radius application ID.')
param appId string

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
        }
      }
    }
  }
}
