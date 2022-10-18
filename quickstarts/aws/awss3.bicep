import aws as aws

import radius as radius

param environment string
param location string = 'global'

resource s3 'AWS.S3/Bucket@default' = {
  name: 'my-bucket-14829032'
  properties: {
    BucketName: 'my-bucket-14829032'
    AccessControl: 'PublicRead'
  }
}

// get a radius container which uses the s3 bucket
resource app 'Applications.Core/applications@2022-03-15-privatepreview' = {
  name: 'webapp'
  location: location
  properties: {
    environment: environment
  }
}

resource frontend 'Applications.Core/containers@2022-03-15-privatepreview' = {
  name: 'frontend'
  location: location
  properties: {
    application: app.id
    container: {
      env: {
      }
      image: 'jkotalik.azurecr.io/awstutorialapp:latest'
    }
  }
}
