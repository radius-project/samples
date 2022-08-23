import aws as aws
import radius as radius

@description('resource id of the radius environment')
param environment string

@description('name of the database. used for radius connector')
param dbname string = 'tododb'

@description('name of the docdb cluster')
param clusterName string = '${dbname}-${uniqueString(environment)}'

@description('name of the docdb instance')
param instanceName string = '${dbname}-${uniqueString(environment)}'

@secure()
@description('username for the cluster')
#disable-next-line secure-parameter-default
param username string = 'adminUs3r'

@secure()
@description('password for the cluster')
#disable-next-line secure-parameter-default
param password string = 'v3rys3cur3Pa55w0rd'

resource db 'Applications.Connector/mongoDatabases@2022-03-15-privatepreview' = {
  name: dbname
  location: 'global'
  properties: {
    environment: environment
    host: cluster.properties.Endpoint
    port: 27017
    secrets: {
      connectionString: 'mongodb://${username}:${password}@${cluster.properties.Endpoint}:${cluster.properties.Port}/${dbname}?sample-database?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false'
      username: username
      password: password
    }
  }
}

resource params 'AWS.DocDB/DBClusterParameterGroup@default' = {
  name: clusterName
  properties: {
    Description: 'parameters for a simple DocDB (no TLS)'
    Family: 'docdb3.6'
    Name: clusterName
    Parameters: {
      audit_logs: 'disabled'
      tls: 'enabled'
      ttl_monitor: 'enabled'
    }
  }
}

resource cluster 'AWS.DocDB/DBCluster@default' = {
  name: clusterName
  properties: {
    DBClusterIdentifier: clusterName
    DBClusterParameterGroupName: params.properties.Name
    MasterUsername: username
    MasterUserPassword: password
    EngineVersion: '4.0.0'
  }
}

resource instance 'AWS.DocDB/DBInstance@default' = {
  name: instanceName
  properties: {
    DBClusterIdentifier: cluster.properties.DBClusterIdentifier
    DBInstanceIdentifier: instanceName
    DBInstanceClass: 'db.t3.medium'
  }
}
