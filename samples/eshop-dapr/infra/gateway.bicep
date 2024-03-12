import radius as radius

@description('The Radius application ID.')
param appId string

//-----------------------------------------------------------------------------
// Create the Radius gateway
//-----------------------------------------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' = {
  name: 'gateway'
  properties: {
    application: appId
    routes: [
      // Identity API
      {
        path: '/identity/'
        destination: 'http://identity-api'
      }
      // Seq
      {
        path: '/log/' // Use trailing slash until redirects are supported
        destination: 'http://seq:5340'
        replacePrefix: '/'
      }
      // Health
      {
        path: '/health'
        destination: 'http://webstatus'
      }
      // Webshopping API Gateway
      {
        path: '/api/'
        destination: 'http://webshopping-gw'
        replacePrefix: '/'
      }
      // Blazor Client
      {
        path: '/'
        destination: 'http://blazor-client'
      }
    ]
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output gatewayName string = gateway.name
