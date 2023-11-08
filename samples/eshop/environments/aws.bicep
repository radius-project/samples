import radius as rad

@description('Account ID of the AWS account resources should be deployed in')
param awsAccountId string

@description('AWS region that resources should be deployed in')
param awsRegion string

@description('Name of your EKS cluster')
param eksClusterName string

resource environment 'Applications.Core/environments@2023-10-01-preview' = {
  name: 'aws'
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
        default: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/recipes/aws/sqldatabases:latest'
          parameters: {
            eksClusterName: eksClusterName
          }
        }
      }
      'Applications.Datastores/redisCaches': {
        default: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/recipes/aws/rediscaches:latest'
          parameters: {
            eksClusterName: eksClusterName
          }
        }
      }
      // Use containerized RabbitMQ instead of Amazon SQS
      // https://github.com/radius-project/bicep-types-aws/blob/main/docs/reference/limitations.md
      'Applications.Messaging/rabbitMQQueues': {
        default: {
          templateKind: 'bicep'
          templatePath: 'ghcr.io/radius-project/recipes/local-dev/rabbitmqmessagequeues:latest'
        }
      }
    }
  }
}
