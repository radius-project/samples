@description('Radius-provided object containing information about the resouce calling the Recipe')
param context object

@description('The geo-location where the resource lives.')
param location string = resourceGroup().location

@description('SQL administrator username')
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

@description('Database name')
param database string

@description('The type of MSSQL server to deploy. Valid values: (Basic, Standard, Premium)')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Standard'

@description('The size of the MSSQL server to deploy. Valid values: for C (Basic/Standard) family (0, 1, 2, 3, 4, 5, 6), for P (Premium) family (1, 2, 3, 4).')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuTier string = 'Standard'

var mssqlPort = 1433

resource mssql 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: 'eshop-mssql-${uniqueString(context.resource.id, resourceGroup().id)}'
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
  }

  resource firewallAllowEverything 'firewallRules' = {
    name: 'firewall-allow-everything'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }

  resource db 'databases' = {
    name: database
    location: location
    sku: {
      name: skuName
      tier: skuTier
    }
  }
}

output result object = {
  values: {
    server: mssql.properties.fullyQualifiedDomainName
    port: mssqlPort
    database: mssql::db.name
    username: adminLogin
  }
  secrets: {
    #disable-next-line outputs-should-not-contain-secrets
    password: adminPassword
    #disable-next-line outputs-should-not-contain-secrets
    connectionString: 'Server=tcp:${mssql.properties.fullyQualifiedDomainName},${mssqlPort};Initial Catalog=${mssql::db.name};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
  }
}
