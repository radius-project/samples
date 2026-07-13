extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('Database admin password. Marked @secure(); Radius encrypts it and injects it into the recipe and the pgweb connection URL.')
@secure()
param password string

@description('Optional image build platform. Empty uses the containerImages recipe default.')
param buildPlatform string = ''

var databaseName = 'appdb'

var databaseUsername = 'radadmin'

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'postgresql-pgweb-test'
  properties: {
    environment: environment
  }
}

resource postgresql 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'postgresql'
  properties: {
    environment: environment
    application: app.id
    size: 'S'
    database: databaseName

    username: databaseUsername
    password: password
  }
}

resource pgwebImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'pgweb-image'
  properties: {
    environment: environment
    application: app.id

    tag: 'v0.17.0'
    build: union(
      {
        source: 'git::https://github.com/sosedoff/pgweb.git//?ref=v0.17.0'
        args: {
          BUILDKIT_CONTEXT_KEEP_GIT_DIR: '1'
        }
      },
      empty(buildPlatform)
        ? {}
        : {
            platforms: [
              buildPlatform
            ]
          }
    )
  }
}

resource pgwebctr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'pgwebctr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      pgweb: {
        image: pgwebImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8081
          }
        }
        env: {
          PGWEB_DATABASE_URL: {
            value: 'postgres://${databaseUsername}:${password}@${postgresql.properties.host}:5432/${databaseName}?sslmode=require'
          }
        }
      }
    }
  }
}
