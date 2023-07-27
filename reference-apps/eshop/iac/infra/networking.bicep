import radius as rad

// PARAMETERS ------------------------------------------------------------
@description('Radius application ID')
param application string

// GATEWAY ---------------------------------------------------------

resource gateway 'Applications.Core/gateways@2022-03-15-privatepreview' = {
  name: 'gateway'
  properties: {
    application: application
    routes: [
      {
        path: '/identity-api'
        destination: identityHttp.id
      }
      {
        path: '/ordering-api'
        destination: orderingHttp.id
      }
      {
        path: '/basket-api'
        destination: basketHttp.id
      }
      {
        path: '/webhooks-api'
        destination: webhooksHttp.id
      }
      {
        path: '/webshoppingagg'
        destination: webshoppingaggHttp.id
      }
      {
        path: '/webshoppingapigw'
        destination: webshoppingapigwHttp.id
      }
      {
        path: '/webhooks-web'
        destination: webhooksclientHttp.id
      }
      {
        path: '/webstatus'
        destination: webstatusHttp.id
      }
      {
        path: '/'
        destination: webspaHttp.id
      }
      {
        path: '/webmvc'
        destination: webmvcHttp.id
      }
    ]
  }
}


// ROUTES ----------------------------------------------------------

resource basketHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'basket-http'
  properties: {
    application: application
    port: 5103
  }
}

resource basketGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'basket-grpc'
  properties: {
    application: application
    port: 9103
  }
}

resource catalogHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'catalog-http'
  properties: {
    application: application
    port: 5101
  }
}

resource catalogGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'catalog-grpc'
  properties: {
    application: application
    port: 9101
  }
}

resource identityHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'identity-http'
  properties: {
    application: application
    port: 5105
  }
}

resource orderingHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'ordering-http'
  properties: {
    application: application
    port: 5102
  }
}

resource orderingGrpc 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'ordering-grpc'
  properties: {
    application: application
    port: 9102
  }
}

resource orderingsignalrhubHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'orderingsignalrhub-http'
  properties: {
    application: application
    port: 5112
  }
}

resource orderbgtasksHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'orderbgtasks-http'
  properties: {
    application: application
    port: 5111
  }
}

resource paymentHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'payment-http'
  properties: {
    application: application
    port: 5108
  }
}

resource seqHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'seq-http'
  properties: {
    application: application
    port: 5340
  }
}

resource webspaHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webspa-http'
  properties: {
    application: application
    port: 5104
  }
}

resource webmvcHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webmvc-http'
  properties: {
    application: application
    port: 5100
  }
}

resource webhooksHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webhooks-http'
  properties: {
    application: application
    port: 5113
  }
}

resource webhooksclientHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webhooksclient-http'
  properties: {
    application: application
    port: 5114
    hostname: '/webhooks-web'
  }
}

resource webshoppingaggHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshoppingagg-http'
  properties: {
    application: application
    port: 5121
  }
}

resource webshoppingapigwHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw-http'
  properties: {
    application: application
    port: 5202
  }
}

resource webshoppingapigwHttp2 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshoppingapigw-http-2'
  properties: {
    application: application
    port: 15202
  }
}

resource webstatusHttp 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webstatus-http'
  properties: {
    application: application
    port: 8107
  }
}

// OUTPUTS --------------------------------------------------------------------

@description('Name of the Gateway')
output gateway string = gateway.name

@description('Name of the Basket HTTP route')
output basketHttp string = basketHttp.name

@description('Name of the Basket gRPC route')
output basketGrpc string = basketGrpc.name

@description('Name of the Catalog HTTP route')
output catalogHttp string = catalogHttp.name

@description('Name of the Catalog gRPC route')
output catalogGrpc string = catalogGrpc.name

@description('Name of the Identity HTTP route')
output identityHttp string = identityHttp.name

@description('Name of the Ordering HTTP route')
output orderingHttp string = orderingHttp.name

@description('Name of the Ordering gRPC route')
output orderingGrpc string = orderingGrpc.name

@description('Name of the Ordering SignalR Hub HTTP route')
output orderingsignalrhubHttp string = orderingsignalrhubHttp.name

@description('Name of the Ordering Background Tasks HTTP route')
output orderbgtasksHttp string = orderbgtasksHttp.name

@description('Name of the Payment HTTP route')
output paymentHttp string = paymentHttp.name

@description('Name of the SEQ HTTP route')
output seqHttp string = seqHttp.name

@description('Name of the WebSPA HTTP route')
output webspaHttp string = webspaHttp.name

@description('Name of the WebMVC HTTP route')
output webmvcHttp string = webmvcHttp.name

@description('Name of the Webhooks HTTP route')
output webhooksHttp string = webhooksHttp.name

@description('Name of the Webhooks Client HTTP route')
output webhooksclientHttp string = webhooksclientHttp.name

@description('Name of the WebShopping Aggregator HTTP route')
output webshoppingaggHttp string = webshoppingaggHttp.name

@description('Name of the WebShopping API Gateway HTTP route')
output webshoppingapigwHttp string = webshoppingapigwHttp.name

@description('Name of the WebShopping API Gateway HTTP route')
output webshoppingapigwHttp2 string = webshoppingapigwHttp2.name

@description('Name of the WebStatus HTTP route')
output webstatusHttp string = webstatusHttp.name

