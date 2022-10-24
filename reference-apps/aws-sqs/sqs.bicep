import aws as aws
import radius as radius

param location string = 'global'
param environment string
param queueName string

@secure()
param aws_access_key_id string
@secure()
param aws_secret_access_key string
param aws_region string

resource queue 'AWS.SQS/Queue@default' = {
  name: queueName
}

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'sqs-emitter-receiver'
  location: location
  properties: {
    environment: environment
  }
}

resource producer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'producer'
  location: location
  properties: {
    application: app.id
    container: {
      env: {
        SQS_QUEUE_URL: queue.properties.QueueUrl
        AWS_ACCESS_KEY_ID: aws_access_key_id
        AWS_SECRET_ACCESS_KEY: aws_secret_access_key
        AWS_REGION: aws_region
      }
      image: 'radius.azurecr.io/quickstarts/aws-sqs-sample:edge'
    }
  }
}
