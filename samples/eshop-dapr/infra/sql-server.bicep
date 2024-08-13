extension radius

@description('The Radius application ID.')
param appId string

@description('The Radius environment name.')
param environment string

@description('The Azure region where the resources will be deployed.')
param location string = resourceGroup().location

@description('The unique seed used to generate resource names.')
param uniqueSeed string = resourceGroup().id

@description('The name of the SQL Server.')
param sqlServerName string = 'sql-${uniqueString(uniqueSeed)}'

@description('The SQL administrator login name.')
param sqlAdministratorLogin string  = 'server_admin'
@description('The SQL administrator login password.')
@secure()
param sqlAdministratorLoginPassword string

@description('The name of the Catalog database.')
param catalogDbName string = 'Microsoft.eShopOnDapr.Services.CatalogDb'

@description('The name of the Identity database.')
param identityDbName string = 'Microsoft.eShopOnDapr.Services.IdentityDb'

@description('The name of the Ordering database.')
param orderingDbName string = 'Microsoft.eShopOnDapr.Services.OrderingDb'

@description('The name of the Key Vault to add the connection strings to.')
param keyVaultName string

//-----------------------------------------------------------------------------
// Create the SQL Server and databases
//-----------------------------------------------------------------------------

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

//-----------------------------------------------------------------------------
// Add connection strings to Key Vault
//-----------------------------------------------------------------------------

resource keyVault 'Microsoft.KeyVault/vaults@2021-11-01-preview' existing = {
  name: keyVaultName

  resource catalogDBConnectionStringSecret 'secrets' = {
    name: 'ConnectionStrings--CatalogDB'
    properties: {
      value: 'Server=tcp:${catalogDb.properties.server},1433;Initial Catalog=${catalogDb.properties.database};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    }
  }

  resource identityDBConnectionStringSecret 'secrets' = {
    name: 'ConnectionStrings--IdentityDB'
    properties: {
      value: 'Server=tcp:${identityDb.properties.server},1433;Initial Catalog=${identityDb.properties.database};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    }
  }

  resource orderingDBConnectionStringSecret 'secrets' = {
    name: 'ConnectionStrings--OrderingDB'
    properties: {
      value: 'Server=tcp:${orderingDb.properties.server},1433;Initial Catalog=${orderingDb.properties.database};Persist Security Info=False;User ID=${sqlAdministratorLogin};Password=${sqlAdministratorLoginPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
    }
  }
}

//-----------------------------------------------------------------------------
// Create Radius portable resources to the databases
//-----------------------------------------------------------------------------

resource catalogDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
  name: 'catalog-db-link'
  properties: {
    application: appId
    environment: environment
    resourceProvisioning: 'manual'
    resources: [
      {
        id: sqlServer::catalogDb.id
      }
    ]
    database: sqlServer::catalogDb.name
    server: sqlServer.properties.fullyQualifiedDomainName
    port: 1433
  }
}

resource identityDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
  name: 'identity-db-link'
  properties: {
    application: appId
    environment: environment
    resourceProvisioning: 'manual'
    resources: [
      {
        id: sqlServer::identityDb.id
      }
    ]
    database: sqlServer::identityDb.name
    server: sqlServer.properties.fullyQualifiedDomainName
    port: 1433
  }
}

resource orderingDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' = {
  name: 'ordering-db-link'
  properties: {
    application: appId
    environment: environment
    resourceProvisioning: 'manual'
    resources: [
      {
        id: sqlServer::orderingDb.id
      }
    ]
    database: sqlServer::orderingDb.name
    server: sqlServer.properties.fullyQualifiedDomainName
    port: 1433
  }
}

//-----------------------------------------------------------------------------
// Output
//-----------------------------------------------------------------------------

output catalogDbName string = catalogDb.name
output identityDbName string = identityDb.name
output orderingDbName string = orderingDb.name
