import aws as aws

@description('Radius-provided object containing information about the resource calling the Recipe')
param context object

@description('Name of the EKS cluster used for app deployment')
param eksClusterName string

@description('List of subnetIds for the subnet group')
param subnetIds array = []

resource eksCluster 'AWS.EKS/Cluster@default' existing = {
  alias: eksClusterName
  properties: {
    Name: eksClusterName
  }
}

param memoryDBSubnetGroupName string = 'eshop-memorydb-subnetgroup-${uniqueString(context.resource.id)}'
resource subnetGroup 'AWS.MemoryDB/SubnetGroup@default' = {
  alias: memoryDBSubnetGroupName
  properties: {
    SubnetGroupName: memoryDBSubnetGroupName
    SubnetIds: ((empty(subnetIds)) ? eksCluster.properties.ResourcesVpcConfig.SubnetIds : concat(subnetIds,eksCluster.properties.ResourcesVpcConfig.SubnetIds))
  }
}

param memoryDBClusterName string = 'eshop-memorydb-cluster-${uniqueString(context.resource.id)}'
resource memoryDBCluster 'AWS.MemoryDB/Cluster@default' = {
  alias: memoryDBClusterName
  properties: {
    ClusterName: memoryDBClusterName
    NodeType: 'db.t4g.small'
    ACLName: 'open-access'
    SecurityGroupIds: [eksCluster.properties.ClusterSecurityGroupId] 
    SubnetGroupName: subnetGroup.name
    NumReplicasPerShard: 0
  }
}

output result object = {
  values: {
    host: memoryDBCluster.properties.ClusterEndpoint.Address
    port: memoryDBCluster.properties.ClusterEndpoint.Port
  }
  secrets: {
    url: '${memoryDBCluster.properties.ClusterEndpoint.Address}:${memoryDBCluster.properties.ClusterEndpoint.Port}'
  }
}
