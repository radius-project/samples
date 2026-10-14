extension radius

@description('The Radius Environment ID. Injected automatically by the rad CLI.')
param environment string

@description('The administrator password for the PostgreSQL database. Supply through a protected parameter file.')
@secure()
param password string

@description('A verified TLS-capable demo image. Use a retained published digest, or an explicitly built local test image.')
@minLength(1)
param image string

@description('Public PEM CA certificate bundle used to verify the PostgreSQL server. Never supply a private key.')
@minLength(1)
param postgresqlCaCertificate string

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
          RADIUS_DEMO_POSTGRESQL_TLS: {
            value: 'verify-full'
          }
          RADIUS_DEMO_POSTGRESQL_CA_FILE: {
            value: '/etc/postgresql-ca/ca.crt'
          }
        }
        volumeMounts: [
          {
            volumeName: 'postgresql-ca'
            mountPath: '/etc/postgresql-ca'
          }
        ]
        ports: {
          web: {
            containerPort: 3000
          }
        }
      }
    }
    volumes: {
      'postgresql-ca': {
        secretName: postgresqlCa.name
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
  // A name reference alone need not order deployment of the Secret Recipe.
  dependsOn: [
    #disable-next-line no-unnecessary-dependson
    postgresqlCa
  ]
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
    tls: 'required'
  }
}

resource postgresqlCa 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'postgresql-ca-${environmentName}'
  properties: {
    environment: environment
    application: demoApp.id
    data: {
      'ca.crt': {
        #disable-next-line use-secure-value-for-secure-inputs
        value: postgresqlCaCertificate
      }
    }
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
