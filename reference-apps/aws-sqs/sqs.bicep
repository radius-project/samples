import aws as aws
import radius as radius

param location string = 'global'
param environment string
param app_name string

@secure()
param aws_access_key_id string
@secure()
param aws_secret_access_key string
param aws_region string

var awsCredential = {
  AWS_ACCESS_KEY_ID: aws_access_key_id
  AWS_SECRET_ACCESS_KEY: aws_secret_access_key
  AWS_REGION: aws_region
}

resource queue 'AWS.SQS/Queue@default' = {
  name: '${app_name}-queue'
  properties: {
    QueueName: '${app_name}-queue'
  }
}

resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: app_name
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
      env: union(
        {
          SQS_QUEUE_URL: queue.properties.QueueUrl
          HTTP_SERVER_PORT: '3000'
        },
        awsCredential
      )
      image: 'radius.azurecr.io/reference-apps/aws-sqs-sample:edge'
    }
  }
}

resource consumer 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'consumer'
  location: location
  properties: {
    application: app.id
    container: {
      env: union(
        {
          SQS_QUEUE_URL: queue.properties.QueueUrl
          HTTP_SERVER_PORT: '4000'
        },
        awsCredential
      )
      image: 'radius.azurecr.io/reference-apps/aws-sqs-sample:edge'
    }
  }
}
