import radius as radius

param environment string

param ucpLocation string = 'global'
param azureLocation string = resourceGroup().location

param adminLogin string = 'sqladmin'
@secure()
param adminPassword string = newGuid()

resource eshop 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'eshop'
  location: ucpLocation
  properties: {
    environment: environment
  }
}

resource containerA 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'containera'
  location: ucpLocation
  properties: {
    application: eshop.id
    container: {
      image: 'nginx:latest'
    }
    connections: {
      connector: {
        source: sqlIdentityDb.id
      }
    }
  }
}

resource httpRouteA 'Applications.Core/httpRoutes@2022-03-15-privatepreview' = {
  name: 'httproutea'
  location: ucpLocation
  properties: {
    application: eshop.id
  }
}

resource containerB 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'containerb'
  location: ucpLocation
  properties: {
    application: eshop.id
    container: {
      image: 'nginx:latest'
    }
    connections: {
      containera: {
        source: httpRouteA.id
      }
    }
  }
}

resource containerC 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'containerc'
  location: ucpLocation
  properties: {
    application: eshop.id
    container: {
      image: 'nginx:latest'
    }
  }
}

resource sql 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: 'eshopsql${uniqueString(resourceGroup().id)}'
  location: azureLocation
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
  }

  // Allow communication from all other Azure resources
  resource allowAzureResources 'firewallRules' = {
    name: 'allow-azure-resources'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  resource identityDb 'databases' = {
    name: 'IdentityDb'
    location: azureLocation
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

  resource catalogDb 'databases' = {
    name: 'CatalogDb'
    location: azureLocation
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

  resource orderingDb 'databases' = {
    name: 'OrderingDb'
    location: azureLocation
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

  resource webhooksDb 'databases' = {
    name: 'WebhooksDb'
    location: azureLocation
    sku: {
      name: 'Standard'
      tier: 'Standard'
    }
  }

}

resource sqlIdentityDb 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  location: ucpLocation
  properties: {
    application: eshop.id
    environment: environment
    resource: sql::identityDb.id
  }
}

resource sqlCatalogDb 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  location: ucpLocation
  properties: {
    application: eshop.id
    environment: environment
    resource: sql::catalogDb.id
  }
}

resource sqlOrderingDb 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  location: ucpLocation
  properties: {
    application: eshop.id
    environment: environment
    resource: sql::orderingDb.id
  }
}

resource sqlWebhooksDb 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  location: ucpLocation
  properties: {
    application: eshop.id
    environment: environment
    resource: sql::webhooksDb.id
  }
}
