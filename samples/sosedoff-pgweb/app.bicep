extension radius

param environment string

param buildSource string = 'git::https://github.com/sosedoff/pgweb.git?ref=6b0b0244d1aefd6971999b03481eeeaa4ec7cf55'

@secure()
param postgresPassword string

var postgresUsername = 'radadmin'
var postgresDatabase = 'pgweb'

resource pgwebApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'pgweb'
  properties: {
    environment: environment
  }
}

resource postgres 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'postgres'
  properties: {
    environment: environment
    application: pgwebApp.id
    size: 'S'
    database: postgresDatabase
    username: postgresUsername
    password: postgresPassword
  }
}

resource pgwebImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'pgweb-image'
  properties: {
    environment: environment
    application: pgwebApp.id
    build: {
      source: buildSource
      platforms: [
        'linux/amd64'
      ]
      args: {
        BUILDKIT_CONTEXT_KEEP_GIT_DIR: '1'
      }
    }
  }
}

resource pgwebContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'pgweb'
  properties: {
    environment: environment
    application: pgwebApp.id
    containers: {
      pgweb: {
        image: pgwebImage.properties.imageReference
        args: [
          '--host=$(PGWEB_DB_HOST)'
          '--user=$(PGWEB_DB_USER)'
          '--pass=$(PGWEB_DB_PASSWORD)'
          '--db=$(PGWEB_DB_NAME)'
          '--ssl=$(PGWEB_DB_SSL)'
        ]
        ports: {
          web: {
            containerPort: 8081
          }
        }
        env: {
          PGWEB_DB_HOST: {
            value: postgres.properties.host
          }
          PGWEB_DB_USER: {
            value: postgresUsername
          }
          PGWEB_DB_PASSWORD: {
            value: postgresPassword
          }
          PGWEB_DB_NAME: {
            value: postgresDatabase
          }
          PGWEB_DB_SSL: {
            value: 'verify-full'
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/'
            port: 8081
          }
        }
      }
    }
    connections: {
      postgresdb: {
        source: postgres.id
        disableDefaultEnvVars: true
      }
    }
  }
}
