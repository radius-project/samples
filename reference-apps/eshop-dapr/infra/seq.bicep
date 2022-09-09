import radius as radius

param appId string

resource seq 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'seq'
  location: 'global'
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

resource seqRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'seq-route'
  location: 'global'
  properties: {
    application: appId
  }
}

output seqRouteName string = seqRoute.name
