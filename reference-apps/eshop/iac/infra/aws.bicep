import radius as radius
import aws as aws

@description('Radius Environment ID')
param environment string

@description('Radius Application ID')
param application string

@description('SQL administrator username')
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

@description('Name of the EKS cluster where the application will be run. Used to setup subnet groups')
param eksClusterName string

// Infrastructure ------------------------------------------------------------

resource eksCluster 'AWS.EKS/Cluster@default' existing = {
  alias: eksClusterName
  properties: {
    Name: eksClusterName
  }
}

var sqlSubnetGroupName = 'eshopsqlsg${uniqueString(application)}'
resource sqlSubnetGroup 'AWS.RDS/DBSubnetGroup@default' = {
  alias: sqlSubnetGroupName
  properties: {
    DBSubnetGroupName: sqlSubnetGroupName
    DBSubnetGroupDescription: sqlSubnetGroupName
    SubnetIds: eksCluster.properties.ResourcesVpcConfig.SubnetIds
  }
}

var identityDbIdentifier = 'eshopidentitysql${uniqueString(application)}'
resource identityDb 'AWS.RDS/DBInstance@default' = {
  alias: identityDbIdentifier
  properties: {
    DBInstanceIdentifier: identityDbIdentifier
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    Port: '1433'
    DBSubnetGroupName: sqlSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

var catalogDbIdentifier = 'eshopcatalogsql${uniqueString(application)}'
resource catalogDb 'AWS.RDS/DBInstance@default' = {
  alias: catalogDbIdentifier
  properties: {
    DBInstanceIdentifier: catalogDbIdentifier
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    Port: '1433'
    DBSubnetGroupName: sqlSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

var orderingDbIdentifier = 'eshoporderingsql${uniqueString(application)}'
resource orderingDb 'AWS.RDS/DBInstance@default' = {
  alias: orderingDbIdentifier
  properties: {
    DBInstanceIdentifier: orderingDbIdentifier
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    Port: '1433'
    DBSubnetGroupName: sqlSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

var webhooksDbIdentifier = 'eshopwebhookssql${uniqueString(application)}'
resource webhooksDb 'AWS.RDS/DBInstance@default' = {
  alias: webhooksDbIdentifier
  properties: {
    DBInstanceIdentifier: webhooksDbIdentifier
    Engine: 'sqlserver-ex'
    EngineVersion: '15.00.4153.1.v1'
    DBInstanceClass: 'db.t3.large'
    AllocatedStorage: '20'
    MaxAllocatedStorage: 30
    MasterUsername: adminLogin
    MasterUserPassword: adminPassword
    Port: '1433'
    DBSubnetGroupName: sqlSubnetGroup.properties.DBSubnetGroupName
    VPCSecurityGroups: [eksCluster.properties.ClusterSecurityGroupId]
    PreferredMaintenanceWindow: 'Mon:00:00-Mon:03:00'
    PreferredBackupWindow: '03:00-06:00'
    LicenseModel: 'license-included'
    Timezone: 'GMT Standard Time'
    CharacterSetName: 'Latin1_General_CI_AS'
  }
}

var redisSubnetGroupName = 'eshopredissg${uniqueString(application)}'
resource redisSubnetGroup 'AWS.MemoryDB/SubnetGroup@default' = {
  alias: redisSubnetGroupName
  properties: {
    SubnetGroupName: redisSubnetGroupName
    SubnetIds: eksCluster.properties.ResourcesVpcConfig.SubnetIds
  }
}

var keystoreCacheName = 'eshopkeystore${uniqueString(application)}'
resource keystoreCache 'AWS.MemoryDB/Cluster@default' = {
  alias: keystoreCacheName
  properties: {
    ClusterName: keystoreCacheName
    NodeType: 'db.t4g.small'
    ACLName: 'open-access'
    SecurityGroupIds: [eksCluster.properties.ClusterSecurityGroupId]
    SubnetGroupName: redisSubnetGroup.properties.SubnetGroupName
    NumReplicasPerShard: 0
  }
}

var basketCacheName = 'eshopbasket${uniqueString(application)}'
resource basketCache 'AWS.MemoryDB/Cluster@default' = {
  alias: basketCacheName
  properties: {
    ClusterName: basketCacheName
    NodeType: 'db.t4g.small'
    ACLName: 'open-access'
    SecurityGroupIds: [eksCluster.properties.ClusterSecurityGroupId]
    SubnetGroupName: redisSubnetGroup.name
    NumReplicasPerShard: 0
  }
}

// TEMP: Using containerized rabbitMQ instead of AWS SNS until AWS nonidempotency is resolved
resource rabbitmqContainer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'rabbitmq-container-eshop-event-bus'
  properties: {
    application: application
    container: {
      image: 'rabbitmq:3.9'
      env: {}
      ports: {
        rabbitmq: {
          containerPort: 5672
          provides: rabbitmqRoute.id
        }
      }
    }
  }
}

resource rabbitmqRoute 'Applications.Core/httproutes@2022-03-15-privatepreview' = {
  name: 'rabbitmq-route-eshop-event-bus'
  properties: {
    application: application
    port: 5672
  }
}

// Links ----------------------------------------------------------------------------
// TODO: Move the Link definitions into the application and use Recipes instead

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    database: 'IdentityDb'
    server: identityDb.properties.Endpoint.Address
    port:  int(identityDb.properties.Endpoint.Port)
    username: adminLogin
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${identityDb.properties.Endpoint.Address},${identityDb.properties.Endpoint.Port};Initial Catalog=IdentityDb;User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    }
  }
}

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    database: 'CatalogDb'
    server: catalogDb.properties.Endpoint.Address
    port: int(catalogDb.properties.Endpoint.Port)
    username: adminLogin
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${catalogDb.properties.Endpoint.Address},${catalogDb.properties.Endpoint.Port};Initial Catalog=CatalogDb;User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    }
  }
}

resource sqlOrderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    database: 'OrderingDb'
    server: orderingDb.properties.Endpoint.Address
    port: int(orderingDb.properties.Endpoint.Port)
    username: adminLogin
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${orderingDb.properties.Endpoint.Address},${orderingDb.properties.Endpoint.Port};Initial Catalog=OrderingDb;User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    }
  }
}

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    database: 'WebhooksDb'
    server: webhooksDb.properties.Endpoint.Address
    port: int(webhooksDb.properties.Endpoint.Port)
    username: adminLogin
    secrets: {
      password: adminPassword
      connectionString: 'Server=tcp:${webhooksDb.properties.Endpoint.Address},${webhooksDb.properties.Endpoint.Port};Initial Catalog=WebhooksDb;User Id=${adminLogin};Password=${adminPassword};Encrypt=false'
    }
  }
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'keystore-data'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    host: keystoreCache.properties.ClusterEndpoint.Address
    port: keystoreCache.properties.ClusterEndpoint.Port
    secrets: {
      connectionString: '${keystoreCache.properties.ClusterEndpoint.Address}:${keystoreCache.properties.ClusterEndpoint.Port},ssl=true'
    }
  }
}

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    host: basketCache.properties.ClusterEndpoint.Address
    port: basketCache.properties.ClusterEndpoint.Port
    secrets: {
      connectionString: '${basketCache.properties.ClusterEndpoint.Address}:${basketCache.properties.ClusterEndpoint.Port},ssl=true'
    }
  }
}

resource rabbitmq 'Applications.Link/rabbitmqMessageQueues@2022-03-15-privatepreview' = {
  name: 'eshop-event-bus'
  properties: {
    application: application
    environment: environment
    resourceProvisioning: 'manual'
    queue: 'eshop-event-bus'
    host: rabbitmqRoute.properties.hostname
    port: rabbitmqRoute.properties.port
    username: 'guest'
    secrets: {
      password: 'guest'
    }
  }
}

// Outputs ------------------------------------

@description('The name of the SQL Identity Link')
output sqlIdentityDb string = sqlIdentityDb.name

@description('The name of the SQL Catalog Link')
output sqlCatalogDb string = sqlCatalogDb.name

@description('The name of the SQL Ordering Link')
output sqlOrderingDb string = sqlOrderingDb.name

@description('The name of the SQL Webhooks Link')
output sqlWebhooksDb string = sqlWebhooksDb.name

@description('The name of the Redis Keystore Link')
output redisKeystore string = redisKeystore.name

@description('The name of the Redis Basket Link')
output redisBasket string = redisBasket.name

@description('The name of the RabbitMQ Link')
output rabbitmq string = rabbitmq.name
