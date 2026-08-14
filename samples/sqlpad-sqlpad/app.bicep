extension radius

param environment string

param buildSource string = 'git::https://github.com/sqlpad/sqlpad.git?ref=ab1f0c03269f0178b9449d34505ce3462271f340'

@secure()
param sqlServerPassword string

var sqlServerUsername = 'radadmin'
var sqlServerDatabase = 'appdb'

resource sqlpadApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'sqlpad'
  properties: {
    environment: environment
  }
}

resource sqlserver 'Radius.Data/sqlServerDatabases@2025-08-01-preview' = {
  name: 'sqlserver'
  properties: {
    environment: environment
    application: sqlpadApp.id
    database: sqlServerDatabase
    username: sqlServerUsername
    password: sqlServerPassword
  }
}

resource sqlpadImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'sqlpad-image'
  properties: {
    environment: environment
    application: sqlpadApp.id
    build: {
      source: buildSource
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource sqlpadContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'sqlpad'
  properties: {
    environment: environment
    application: sqlpadApp.id
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
          SQLPAD_CONNECTIONS__azure_sql__database: {
            value: sqlServerDatabase
          }
          SQLPAD_CONNECTIONS__azure_sql__username: {
            value: sqlServerUsername
          }
          SQLPAD_CONNECTIONS__azure_sql__password: {
            value: sqlServerPassword
          }
          SQLPAD_CONNECTIONS__azure_sql__sqlserverEncrypt: {
            value: 'true'
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/'
            port: 3000
          }
        }
      }
    }
    connections: {
      sqlserverdb: {
        source: sqlserver.id
      }
    }
  }
}
