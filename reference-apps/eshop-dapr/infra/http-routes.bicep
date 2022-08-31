import radius as radius

param appId string

resource basketApiRoute 'Applications.Core/httpRoutes@2022-03-15-privatepreview' = {
  name: 'basket-api-route'
  location: 'global'
  properties: {
    application: appId
  }
}

resource blazorClientRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'blazor-client-route'
  location: 'global'
  properties: {
    application: appId
  }
}

resource catalogApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'catalog-api-route'
  location: 'global'
  properties: {
    application: appId
  }
}

resource identityApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'identity-api-route'
  location: 'global'
  properties: {
    application: appId
  }
}

resource orderingApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'ordering-api-route'
  location: 'global'
  properties: {
    application: appId
  }
}

resource paymentApiRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'payment-api-route'
  location: 'global'
  properties: {
    application: appId
  }
}

resource webshoppingAggRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webshopping-agg-route'
  location: 'global'
  properties: {
    application: appId
  }
}

resource webshoppingGwRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'route-webshopping-gw'
  location: 'global'
  properties: {
    application: appId
  }
}

resource webstatusRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'webstatus-route'
  location: 'global'
  properties: {
    application: appId
  }
}

output basketApiRouteName string = basketApiRoute.name
output blazorClientRouteName string = blazorClientRoute.name
output catalogApiRouteName string = catalogApiRoute.name
output identityApiRouteName string = identityApiRoute.name
output orderingApiRouteName string = orderingApiRoute.name
output paymentApiRouteName string = paymentApiRoute.name
output webshoppingAggRouteName string = webshoppingAggRoute.name
output webshoppingGwRouteName resource = webshoppingGwRoute.name
output webstatusRouteName string = webstatusRoute.name
