import aws as aws

@description('Radius-provided object containing information about the resource calling the Recipe')
param context object

@description('Name of the EKS cluster used for app deployment')
param eksClusterName string

@description('SQL administrator username')
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

@description('Database name')
param database string

resource eksCluster 'AWS.EKS/Cluster@default' existing = {
  alias: eksClusterName
  properties: {
    Name: eksClusterName
  }
}

var rdsSubnetGroupName = 'eshop-rds-dbsubnetgroup-${uniqueString(context.resource.id)}'
resource rdsDBSubnetGroup 'AWS.RDS/DBSubnetGroup@default' = {
  alias: rdsSubnetGroupName
  properties: {
    DBSubnetGroupName: rdsSubnetGroupName
    DBSubnetGroupDescription: rdsSubnetGroupName
    SubnetIds: eksCluster.properties.ResourcesVpcConfig.SubnetIds
  }
}

var rdsDBInstanceName = 'eshop-rds-dbinstance-${uniqueString(context.resource.id)}'
resource rdsDBInstance 'AWS.RDS/DBInstance@default' = {
  alias: rdsDBInstanceName
  properties: {
    DBInstanceIdentifier: rdsDBInstanceName
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    // Port: '1433'
    DBSubnetGroupName: rdsDBSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

output result object = {
  values: {
    server: rdsDBInstance.properties.Endpoint.Address
    port: 1433
    database: database
    username: adminLogin
  }
  secrets: {
    #disable-next-line outputs-should-not-contain-secrets
    connectionString: 'Server=tcp:${rdsDBInstance.properties.Endpoint.Address},${rdsDBInstance.properties.Endpoint.Port};Initial Catalog=${database};User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    #disable-next-line outputs-should-not-contain-secrets
    password: adminPassword
  }
}
