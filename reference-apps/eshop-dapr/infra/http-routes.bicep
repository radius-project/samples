import radius as radius

@description('The Radius Application ID.')
param appId string

//-----------------------------------------------------------------------------
// Create the HTTP routes for the application
//-----------------------------------------------------------------------------

resource basketApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' = {
  name: 'basket-api-route'
  properties: {
    application: appId
  }
}

resource blazorClientRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'blazor-client-route'
  properties: {
    application: appId
  }
}

resource catalogApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'catalog-api-route'
  properties: {
    application: appId
  }
}

resource identityApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'identity-api-route'
  properties: {
    application: appId
  }
}

resource orderingApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'ordering-api-route'
  properties: {
    application: appId
  }
}

resource paymentApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'payment-api-route'
  properties: {
    application: appId
  }
}

resource seqRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'seq-route'
  properties: {
    application: appId
  }
}

resource webshoppingAggRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshopping-agg-route'
  properties: {
    application: appId
  }
}

resource webshoppingGwRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'route-webshopping-gw'
  properties: {
    application: appId
  }
}

resource webstatusRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webstatus-route'
  properties: {
    application: appId
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output basketApiRouteName string = basketApiRoute.name
output blazorClientRouteName string = blazorClientRoute.name
output catalogApiRouteName string = catalogApiRoute.name
output identityApiRouteName string = identityApiRoute.name
output orderingApiRouteName string = orderingApiRoute.name
output paymentApiRouteName string = paymentApiRoute.name
output seqRouteName string = seqRoute.name
output webshoppingAggRouteName string = webshoppingAggRoute.name
output webshoppingGwRouteName string = webshoppingGwRoute.name
output webstatusRouteName string = webstatusRoute.name
