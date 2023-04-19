import radius as radius

param appId string

param blazorClientRouteName string
param identityApiRouteName string
param seqRouteName string
param webshoppingGwRouteName string
param webstatusRouteName string

resource blazorClientRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: blazorClientRouteName
}

resource identityApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: identityApiRouteName
}

resource seqRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: seqRouteName
}

resource webshoppingGwRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webshoppingGwRouteName
}

resource webstatusRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' existing = {
  name: webstatusRouteName
}

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'gateway'
  properties: {
    application: appId
    routes: [
      // Identity API
      {
        path: '/identity/'
        destination: identityApiRoute.id
      }
      // Seq
      {
        path: '/log/' // Use trailing slash until redirects are supported
        destination: seqRoute.id
        replacePrefix: '/'
      }
      // Health
      {
        path: '/health'
        destination: webstatusRoute.id
      }
      // Webshopping API Gateway
      {
        path: '/api/'
        destination: webshoppingGwRoute.id
        replacePrefix: '/'
      }
      // Blazor Client
      {
        path: '/'
        destination: blazorClientRoute.id
      }
    ]
  }
}

output url string = gateway.properties.url
