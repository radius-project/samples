import radius as rad

@description('Account ID of the AWS account resources should be deployed in')
param awsAccountId string

@description('AWS region that resources should be deployed in')
param awsRegion string

@description('Name of your EKS cluster')
param eksClusterName string

resource awsEshopEnv 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'aws-eshop-env'
  properties: {
    compute: {
      kind: 'kubernetes'
      resourceId: 'self'
      namespace: 'aws-eshop'
    }
    providers: {
      aws: {
        scope: '/planes/aws/aws/accounts/${awsAccountId}/regions/${awsRegion}'
      }
    }
    recipes: {
      'Applications.Datastores/sqlDatabases': {
        sqldatabase: {
          templateKind: 'bicep'
          templatePath: 'radiusdev.azurecr.io/recipes/aws/sqldatabases:pr-29'
          parameters: {
            eksClusterName: eksClusterName
          }
        }
      }
      'Applications.Datastores/redisCaches': {
        rediscache: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/aws/rediscaches:edge'
          parameters: {
            eksClusterName: eksClusterName
          }
        }
      }
      // Temporarily using containerized rabbitmq until we can use SQS or AmazonMQ
      'Applications.Messaging/rabbitMQQueues': {
        rabbitmqmessagequeue: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/local-dev/rabbitmqqueues:edge'
        }
      }
    }
  }
}
