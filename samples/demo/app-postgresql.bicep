extension radius

@description('The Radius Environment ID. Injected automatically by the rad CLI.')
param environment string

@description('The administrator password for the PostgreSQL database. Pass via the CLI, e.g. -p password=$(openssl rand -hex 16).')
@secure()
param password string

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
        image: 'ghcr.io/radius-project/samples/demo:latest'
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
      postgresqlcredentials: {
        source: postgresqlClientCredentials.id
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
    database: 'appdb'
    username: 'myadmin'
    password: password
  }
}

resource postgresqlClientCredentials 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'postgresql-client-credentials-${environmentName}'
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
