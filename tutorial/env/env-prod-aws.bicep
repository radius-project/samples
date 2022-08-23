import radius as radius

@description('resource id of the radius environment')
param environment string

@description('name of the database. used for radius connector')
param dbname string = 'tododb'

@secure()
@description('username for the cluster')
#disable-next-line secure-parameter-default
param username string = 'adminUs3r'

@secure()
@description('password for the cluster')
#disable-next-line secure-parameter-default
param password string = 'v3rys3cur3Pa55w0rd'

param hostname string = 'todoapp-docdb.c4at3zbeu0nr.us-west-2.docdb.amazonaws.com'

resource db 'Applications.Connector/mongoDatabases@2022-03-15-privatepreview' = {
  name: dbname
  location: 'global'
  properties: {
    environment: environment
    host: hostname
    port: 27017
    secrets: {
      connectionString: 'mongodb://${username}:${password}@${hostname}:27017/${dbname}?tls=false&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false'
      username: username
      password: password
    }
  }
}
