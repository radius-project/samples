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
      'Applications.Link/sqlDatabases': {
        awsmssql: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/awsmssql:edge'
          parameters: {
            eksClusterName: eksClusterName
          }
        }
      }
      'Applications.Link/redisCaches': {
        awsredis: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/awsredis:edge'
          parameters: {
            eksClusterName: eksClusterName
          }
        }
      }
      'Applications.Link/extenders': {
        awsrabbitmq: {
          templateKind: 'bicep'
          templatePath: 'willsmithradius.azurecr.io/recipes/awsrabbitmq:edge'
        }
      }
    }
  }
}
