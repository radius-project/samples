import aws as aws

param context object 
param subnetIds array
param securityGroupIds array

var subnetGroupName = 'redis-${uniqueString(context.resource.id)}'
var clusterName = 'redis-${uniqueString(context.resource.id)}'

resource subnetGroup 'AWS.MemoryDB/SubnetGroup@default' = {
  alias: subnetGroupName
  name: subnetGroupName
  properties: {
    SubnetGroupName: subnetGroupName
    SubnetIds: subnetIds
  }
}

resource memoryDBCluster 'AWS.MemoryDB/Cluster@default' = {
  alias: clusterName
  name: clusterName
  properties: {
    ClusterName: clusterName
    NodeType: 'db.t4g.small'
    ACLName: 'open-access'
    SecurityGroupIds: securityGroupIds
    SubnetGroupName: subnetGroup.name
  }
}

output result object = {
  values: {
    host: memoryDBCluster.properties.ClusterEndpoint.Address
    port: memoryDBCluster.properties.ClusterEndpoint.Port
  }
}
