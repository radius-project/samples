import radius as radius

param appId string
param environment string
param location string
param uniqueSeed string

param sqlServerName string = 'sql-${uniqueString(uniqueSeed)}'

@secure()
param sqlAdministratorLogin string
@secure()
param sqlAdministratorLoginPassword string

param catalogDbName string
param identityDbName string
param orderingDbName string

resource sqlServer 'Microsoft.Sql/servers@2021-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
  }

  resource sqlServerFirewall 'firewallRules@2021-05-01-preview' = {
    name: 'AllowAllWindowsAzureIps'
    properties: {
      // Allow Azure services and resources to access this server
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  resource catalogDb 'databases@2021-05-01-preview' = {
    name: catalogDbName
    location: location
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
    }
  }

  resource identityDb 'databases@2021-05-01-preview' = {
    name: identityDbName
    location: location
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
    }
  }

  resource orderingDb 'databases@2021-05-01-preview' = {
    name: orderingDbName
    location: location
    properties: {
      collation: 'SQL_Latin1_General_CP1_CI_AS'
    }
  }
}

resource catalogDbLink 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalog-db-link'
  location: location
  properties: {
    application: appId
    environment: environment
    resource: sqlServer::catalogDb.id
    mode: 'resource'
  }
}

resource identityDbLink 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identity-db-link'
  location: location
  properties: {
    application: appId
    environment: environment
    resource: sqlServer::identityDb.id
    mode: 'resource'
  }
}

resource orderingDbLink 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'ordering-db-link'
  location: location
  properties: {
    application: appId
    environment: environment
    resource: sqlServer::orderingDb.id
    mode: 'resource'
  }
}

output catalogDbLinkName string = catalogDbLink.name
output identityDbLinkName string = identityDbLink.name
output orderingDbLinkName string = orderingDbLink.name
