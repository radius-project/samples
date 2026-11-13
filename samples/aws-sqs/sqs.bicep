extension aws
extension radius

param environment string
param queue_name string

@secure()
param aws_access_key_id string
@secure()
param aws_secret_access_key string
param aws_region string

param image string = 'ghcr.io/radius-project/samples/aws-sqs:latest'

var aws_credential = {
  AWS_ACCESS_KEY_ID: {
    value: aws_access_key_id
  }
  AWS_SECRET_ACCESS_KEY: {
    value: aws_secret_access_key
  }
  AWS_REGION: {
    value: aws_region
  }
}

var app_name = 'sqs-sample-app'
resource app 'Applications.Core/applications@2023-10-01-preview' = {
  name: app_name
  properties: {
    environment: environment
  }
}

resource queue 'AWS.SQS/Queue@default' = {
  alias: 'sqs-sample-app-${queue_name}'
  name: 'sqs-sample-app-${queue_name}'
  properties: {
    QueueName: 'sqs-sample-app-${queue_name}'
  }
}

resource producer 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'producer'
  properties: {
    application: app.id
    container: {
      env: union(
        {
          SQS_QUEUE_URL: {
            value: queue.properties.QueueUrl
          }
          HTTP_SERVER_PORT: {
            value: '3000'
          }
        },
        aws_credential
      )
      image: image
    }
  }
}

resource consumer 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'consumer'
  properties: {
    application: app.id
    container: {
      env: union(
        {
          SQS_QUEUE_URL: {
            value: queue.properties.QueueUrl
          }
          HTTP_SERVER_PORT: {
            value: '4000'
          }
        },
        aws_credential
      )
      image: image
    }
  }
}
