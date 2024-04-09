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
        destination: 'http://identity-api:5105'
      }
      {
        path: '/ordering-api'
        destination: 'http://ordering-api:5102'
      }
      {
        path: '/basket-api'
        destination: 'http://basket-api:5103'
      }
      {
        path: '/webhooks-api'
        destination: 'http://webhooks-api:5113'
      }
      {
        path: '/webshoppingagg'
        destination: 'http://webshoppingagg:5121'
      }
      {
        path: '/webshoppingapigw'
        destination: 'http://webshoppingapigw:5202'
      }
      {
        path: '/webhooks-web'
        destination: 'http://webhooks-client:5114'
      }
      {
        path: '/webstatus'
        destination: 'http://webstatus:8107'
      }
      {
        path: '/'
        destination: 'http://web-spa:5104'
      }
      {
        path: '/webmvc'
        destination: 'http://webmvc:5100'
      }
    ]
  }
}

// OUTPUTS --------------------------------------------------------------------

@description('Name of the Gateway')
output gateway string = gateway.name
