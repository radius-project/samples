extension radius

@description('The Radius Environment ID. Injected automatically by the rad CLI.')
param environment string

@description('The administrator password for the PostgreSQL database. Supply a URI-safe random hexadecimal value in a protected parameter file.')
@secure()
param password string

// Defaults to the published image; CI overrides this to test the freshly built image.
param image string = 'ghcr.io/radius-project/samples/demo:latest'

// Environment name derived from the Environment ID, used to keep resource names
// unique per environment (e.g. dev/test/prod) within the same resource group.
var environmentName = last(split(environment, '/'))

resource demoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'demo-${environmentName}'
  properties: {
    environment: environment
  }
}

resource demoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'demo-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    containers: {
      web: {
        image: image
        env: {
          PGSSLMODE: {
            value: 'disable'
          }
        }
        ports: {
          web: {
            containerPort: 3000
          }
        }
      }
    }
    connections: {
      postgresql: {
        source: postgresql.id
      }
      postgresqlCredentials: {
        source: postgresqlCredentials.id
      }
    }
  }
}

resource postgresql 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'postgresql-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    size: 'S'
    tls: 'disabled'
    database: 'appdb'
    username: 'myadmin'
    password: password
  }
}

resource postgresqlCredentials 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'postgresql-credentials-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    data: {
      password: {
        value: password
      }
    }
  }
}
