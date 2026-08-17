extension radius

@description('The Radius Environment ID. Injected automatically by the rad CLI.')
param environment string

@description('Container image for the demo app. Defaults to the published sample image; overridden in CI to test a locally-built image.')
param image string = 'ghcr.io/radius-project/samples/demo:latest'

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

// The demo container needs the same password used to provision the database.
// Store it in a Radius.Security/secrets resource and bind it by reference rather
// than passing it to the container as a plain `env` value: `data.value` is
// x-radius-sensitive, so Radius encrypts it at rest and redacts it on reads,
// whereas a container `env.value` is stored unencrypted on the container
// resource and rendered literally into the pod spec.
resource dbCredentials 'Radius.Security/secrets@2025-08-01-preview' = {
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

resource demoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'demo-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    containers: {
      web: {
        image: image
        // Host, port, username, and database arrive automatically as
        // CONNECTION_POSTGRESQL_* env vars from the connection below. The
        // connection cannot carry the password (x-radius-sensitive properties
        // redact to null on reads and are skipped by the containers recipe), so
        // it is bound by reference here under the same naming scheme, filling
        // the one gap the connection leaves.
        env: {
          CONNECTION_POSTGRESQL_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbCredentials.name
                key: 'password'
              }
            }
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
    }
  }
}
