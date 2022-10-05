import aws as aws
import radius as radius

param environment string
param eksClusterName string = 'prod-aws' 

param basename string = 'db'
param subnetGroupName string = '${basename}-memorydb-subnet-group'
param memoryDBClusterName string = '${basename}-memorydb-cluster'

resource eksCluster 'AWS.EKS/Cluster@default' existing = {
  name: eksClusterName
}

var subnetIds = [
  'subnet-0dde096675d947e96'
  'subnet-0fa35dbf2c93aef32'
]

resource subnetGroup 'AWS.MemoryDB/SubnetGroup@default' = {
  name: subnetGroupName
  properties: {
    SubnetGroupName: subnetGroupName
    //SubnetIds: eksCluster.properties.ResourcesVpcConfig.SubnetIds
    SubnetIds: subnetIds
  }
}

resource memoryDBCluster 'AWS.MemoryDB/Cluster@default' = {
  name: memoryDBClusterName
  properties: {
    ClusterName: memoryDBClusterName
    NodeType: 'db.t4g.small'
    ACLName: 'open-access'
    SecurityGroupIds: [eksCluster.properties.ClusterSecurityGroupId]
    SubnetGroupName: subnetGroup.name
  }
}

resource db 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'db'
  location: 'global'
  properties: {
    mode: 'values'
    environment: environment
    host: memoryDBCluster.properties.ClusterEndpoint.Address
    port: memoryDBCluster.properties.ClusterEndpoint.Port
    secrets: {
      connectionString: 'rediss://${memoryDBCluster.properties.ClusterEndpoint.Address}:${memoryDBCluster.properties.ClusterEndpoint.Port}'
      password: ''
    }
  }
}
