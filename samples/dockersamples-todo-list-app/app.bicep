extension radius
@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('Database admin password. Marked @secure(); Radius encrypts it and injects it into the recipe and the container.')
@secure()
param password string

var databaseName = 'appdb'

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'mysql-azure-app-test'
  properties: {
    environment: environment
  }
}

resource mysql 'Radius.Data/mySqlDatabases@2025-08-01-preview' = {
  name: 'mysql'
  properties: {
    environment: environment
    application: app.id
    version: '8.0'
    database: databaseName

    username: 'radadmin'
    password: password
  }
}

resource todoAppImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'todo-app-image'
  properties: {
    environment: environment
    application: app.id

    tag: 'v1.0.0'
    build: {
      source: 'git::https://github.com/docker/getting-started-todo-app.git//?ref=55680777bc46c59d3fe0ab9ff7e79ee947d0c757'
    }
  }
}

resource todoctr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'todoctr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      todo: {
        image: todoAppImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          MYSQL_HOST: {
            value: mysql.properties.host
          }
          MYSQL_DB: {
            value: databaseName
          }

          MYSQL_USER: {
            value: 'radadmin'
          }
          MYSQL_PASSWORD: {
            value: password
          }
        }
      }
    }
  }
}
