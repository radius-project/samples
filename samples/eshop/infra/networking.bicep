import radius as rad

// PARAMETERS ------------------------------------------------------------
@description('Radius application ID')
param application string

// GATEWAY ---------------------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' = {
  name: 'gateway'
  properties: {
    application: application
    routes: [
      {
        path: '/identity-api'
        destination: 'http://identity-api'
      }
      {
        path: '/ordering-api'
        destination: 'http://ordering-api'
      }
      {
        path: '/basket-api'
        destination: 'http://basket-api'
      }
      {
        path: '/webhooks-api'
        destination: 'http://webhooks-api'
      }
      {
        path: '/webshoppingagg'
        destination: 'http://webshoppingagg'
      }
      {
        path: '/webshoppingapigw'
        destination: 'http://webshoppingapigw'
      }
      {
        path: '/webhooks-web'
        destination: 'http://webhooks-client'
      }
      {
        path: '/webstatus'
        destination: 'http://webstatus'
      }
      {
        path: '/'
        destination: 'http://web-spa'
      }
      {
        path: '/webmvc'
        destination: 'http://webmvc'
      }
    ]
  }
}

// OUTPUTS --------------------------------------------------------------------

@description('Name of the Gateway')
output gateway string = gateway.name
