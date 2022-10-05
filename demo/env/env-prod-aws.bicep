import radius as radius

resource env 'Applications.Core/environments@2022-03-15-privatepreview' = {
  name: 'prod-aws'
  properties: {
    compute: {
      kind: 'kubernetes'
      namespace: 'default'
    }
    providers: {
      aws: {
        scope: '/planes/aws/aws/accounts/664787032730/regions/us-west-2'
      }
    }
    recipes: {
      'Applications.Link/redisCaches': {
        default: {
          templatePath: 'rynowak.azurecr.io/recipes/redis-aws:0.20'
          templateKind: 'bicep'
          parameters: {
            subnetIds: [
              'subnet-06f5665404f25c0b4'
              'subnet-05e5368df71683559'
            ]
            securityGroupIds: [
              'sg-04f59571c8c583ef3'
            ]
          }
        }
      }
    }
  }
}
