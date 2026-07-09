extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('Database admin password. Marked @secure(); Radius encrypts it and injects it into the recipe and the SQLPad connection.')
@secure()
param password string

var databaseName = 'appdb'

var databaseUsername = 'radadmin'

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'sqlpad-azure-app-test'
  properties: {
    environment: environment
  }
}

resource sqlserver 'Radius.Data/sqlServerDatabases@2025-08-01-preview' = {
  name: 'sqlserver'
  properties: {
    environment: environment
    application: app.id
    database: databaseName

    username: databaseUsername
    password: password
  }
}

resource sqlpadImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'sqlpad-image'
  properties: {
    environment: environment
    application: app.id
    tag: 'v7.5.7'
    build: {
      source: 'git::https://github.com/sqlpad/sqlpad.git//?ref=ab1f0c03269f0178b9449d34505ce3462271f340'
    }
  }
}

resource sqlpadctr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'sqlpadctr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      sqlpad: {
        image: sqlpadImage.properties.imageReference
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          SQLPAD_PORT: {
            value: '3000'
          }
          SQLPAD_DB_PATH: {
            value: '/var/lib/sqlpad'
          }
          SQLPAD_AUTH_DISABLED: {
            value: 'true'
          }
          SQLPAD_AUTH_DISABLED_DEFAULT_ROLE: {
            value: 'admin'
          }
          SQLPAD_CONNECTIONS__azure_sql__name: {
            value: 'Azure SQL'
          }
          SQLPAD_CONNECTIONS__azure_sql__driver: {
            value: 'sqlserver'
          }
          SQLPAD_CONNECTIONS__azure_sql__host: {
            value: sqlserver.properties.host
          }
          SQLPAD_CONNECTIONS__azure_sql__port: {
            value: '1433'
          }
          SQLPAD_CONNECTIONS__azure_sql__database: {
            value: databaseName
          }
          SQLPAD_CONNECTIONS__azure_sql__username: {
            value: databaseUsername
          }
          SQLPAD_CONNECTIONS__azure_sql__password: {
            value: password
          }
          SQLPAD_CONNECTIONS__azure_sql__sqlserverEncrypt: {
            value: 'true'
          }
          SQLPAD_CONNECTIONS__azure_sql__trustServerCertificate: {
            value: 'false'
          }
        }
      }
    }
    connections: {
      sqlserver: {
        source: sqlserver.id
      }
    }
  }
}
