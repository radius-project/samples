import radius as radius

param appId string
param environmentId string
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

resource catalogDbConnector 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalog-db-connector'
  location: location
  properties: {
    application: appId
    environment: environmentId
    resource: sqlServer::catalogDb.id
  }
}

resource identityDbConnector 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identity-db-connector'
  location: location
  properties: {
    application: appId
    environment: environmentId
    resource: sqlServer::identityDb.id
  }
}

resource orderingDbConnector 'Applications.Connector/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'ordering-db-connector'
  location: location
  properties: {
    application: appId
    environment: environmentId
    resource: sqlServer::orderingDb.id
  }
}

output catalogDbConnectorName string = catalogDbConnector.name
output identityDbConnectorName string = identityDbConnector.name
output orderingDbConnectorName string = orderingDbConnector.name
