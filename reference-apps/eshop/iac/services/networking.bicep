import radius as rad

// PARAMETERS ------------------------------------------------------------
@description('Radius application ID')
param application string

@description('Radius region to deploy resources into. Only global is supported today')
@allowed([
  'global'
])
param ucpLocation string

// GATEWAY ---------------------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'gateway'
  location: ucpLocation
  properties: {
    application: application
    routes: [
      {
        path: '/identity-api'
        destination: {
          route: 'identity-api'
          port: 5105
        }
      }
      {
        path: '/ordering-api'
        destination: {
          route: 'ordering-api'
          port: 5102
        }
      }
      {
        path: '/basket-api'
        destination: {
          route: 'basket-api'
          port: 5103
        }
      }
      {
        path: '/webhooks-api'
        destination: {
          route: 'webhooks-api'
          port: 5113
        }
      }
      {
        path: '/webshoppingagg'
        destination: {
          route: 'webshoppingagg'
          port: 5121
        }
      }
      {
        path: '/webshoppingapigw'
        destination: {
          route: 'webshoppingapigw'
          port: 5202
        }
      }
      {
        path: '/webhooks-web'
        destination: {
          route: 'webhooks-client'
          port: 5113
        }
      }
      {
        path: '/webstatus'
        destination: {
          route: 'webstatus'
          port: 8107
        }
      }
      {
        path: '/'
        destination: {
          route: 'web-spa'
          port: 5104
        }
      }
      {
        path: '/webmvc'
        destination: {
          route: 'webmvc'
          port: 5100
        }
      }
    ]
  }
}

// OUTPUTS --------------------------------------------------------------------

@description('Name of the Gateway')
output gateway string = gateway.name

