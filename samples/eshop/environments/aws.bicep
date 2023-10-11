import radius as rad

@description('Account ID of the AWS account resources should be deployed in')
param awsAccountId string

@description('AWS region that resources should be deployed in')
param awsRegion string

@description('Name of your EKS cluster')
param eksClusterName string

resource awsEshopEnv 'Applications.Core/environments@2023-10-01-preview' = {
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
      // Use containerized RabbitMQ instead of Amazon SQS
      // https://github.com/radius-project/bicep-types-aws/blob/main/docs/reference/limitations.md
      'Applications.Messaging/rabbitMQQueues': {
        rabbitmqmessagequeue: {
          templateKind: 'bicep'
          templatePath: 'radius.azurecr.io/recipes/local-dev/rabbitmqmessagequeues:edge'
        }
      }
    }
  }
}
