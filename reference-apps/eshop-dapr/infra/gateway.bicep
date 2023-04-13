import radius as radius

@description('The Radius application ID.')
param appId string

@description('The name of the Blazor client HTTP route.')
param blazorClientRouteName string

@description('The name of the Identity API HTTP route.')
param identityApiRouteName string

@description('The name of the Seq HTTP route.')
param seqRouteName string

@description('The name of the gateway HTTP route.')
param webshoppingGwRouteName string

@description('The name of the webstatus API HTTP route.')
param webstatusRouteName string

//-----------------------------------------------------------------------------
// Get references to existing resources 
//-----------------------------------------------------------------------------

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

//-----------------------------------------------------------------------------
// Create the Radius gateway
//-----------------------------------------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'gateway'
  location: 'global'
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

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output gatewayName string = gateway.name
