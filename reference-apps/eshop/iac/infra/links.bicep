import radius as rad

resource sqlIdentityDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: 'identitydb'
}

resource sqlCatalogDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: 'catalogdb'
}

resource sqlOrderingDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: 'orderingdb'
}

resource sqlWebhooksDb 'Applications.Datastores/sqlDatabases@2022-03-15-privatepreview' existing = {
  name: 'webhooksdb'
}

resource redisKeystore 'Applications.Datastores/redisCaches@2022-03-15-privatepreview' existing = {
  name: 'keystore-data'
}

resource redisBasket 'Applications.Datastores/redisCaches@2022-03-15-privatepreview' existing = {
  name: 'basket-data'
}

resource rabbitmq 'Applications.Messaging/rabbitMQQueues@2022-03-15-privatepreview' existing = {
  name: 'eshop-event-bus'
}

// Outputs --------------------------------------------------------------------------

@description('The name of the SQL Database for Identity.')
output sqlIdentityDb string = sqlIdentityDb.name

@description('The name of the SQL Database for Catalog.')
output sqlCatalogDb string = sqlCatalogDb.name

@description('The name of the SQL Database for Ordering.')
output sqlOrderingDb string = sqlOrderingDb.name

@description('The name of the SQL Database for Webhooks.')
output sqlWebhooksDb string = sqlWebhooksDb.name

@description('The name of the Redis Cache for Keystore.')
output redisKeystore string = redisKeystore.name

@description('The name of the Redis Cache for Basket.')
output redisBasket string = redisBasket.name

@description('The name of the RabbitMQ Message Queue.')
output rabbitmq string = rabbitmq.name
