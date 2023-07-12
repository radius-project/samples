import radius as radius
import aws as aws

@description('Radius environment ID')
param environment string

@description('Radius application ID')
param application string

@description('SQL administrator username')
param adminLogin string

@description('SQL administrator password')
@secure()
param adminPassword string

@description('Name of the EKS cluster where the application will be run. Used to setup subnet groups')
param eksClusterName string

resource sqlIdentityDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'identitydb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'aws-mssql'
      parameters: {
        eksClusterName: eksClusterName
        database: 'IdentityDb'
        adminLogin: adminLogin
        adminPassword: adminPassword
      }
    }
  }
}

resource sqlCatalogDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'catalogdb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'aws-mssql'
      parameters: {
        eksClusterName: eksClusterName
        database: 'CatalogDb'
        adminLogin: adminLogin
        adminPassword: adminPassword
      }
    }
  }
}

resource sqlOrderingDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'orderingdb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'aws-mssql'
      parameters: {
        eksClusterName: eksClusterName
        database: 'OrderingDb'
        adminLogin: adminLogin
        adminPassword: adminPassword
      }
    }
  }
}

resource sqlWebhooksDb 'Applications.Link/sqlDatabases@2022-03-15-privatepreview' = {
  name: 'webhooksdb'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'aws-mssql'
      parameters: {
        eksClusterName: eksClusterName
        database: 'WebhooksDb'
        adminLogin: adminLogin
        adminPassword: adminPassword
      }
    }
  }
}

resource redisKeystore 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'keystore-data'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'aws-memorydb'
      parameters: {
        eksClusterName: eksClusterName
      }
    }
  }
}

resource redisBasket 'Applications.Link/redisCaches@2022-03-15-privatepreview' = {
  name: 'basket-data'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'aws-memorydb'
      parameters: {
        eksClusterName: eksClusterName
      }
    }
  }
}

resource rabbitmq 'Applications.Link/extenders@2022-03-15-privatepreview' = {
  name: 'eshop-event-bus'
  properties: {
    application: application
    environment: environment
    recipe: {
      name: 'container-rabbitmq'
    }
  }
}

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
