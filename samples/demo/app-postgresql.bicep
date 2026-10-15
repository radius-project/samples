extension radius

@description('The Radius Environment ID. Injected automatically by the rad CLI.')
param environment string

@description('The administrator password for the PostgreSQL database. Supply through a protected parameter file.')
@secure()
param password string

@description('A verified TLS-capable demo image. Use a retained published digest, or an explicitly built local test image.')
@minLength(1)
param image string

@description('Public PEM CA bundle required with postgresqlTls=required; omit for disabled. Never supply a private key.')
param postgresqlCaCertificate string = ''

@description('Use required for verified TLS, or explicitly choose disabled for a disposable plaintext database.')
@allowed([
  'required'
  'disabled'
])
param postgresqlTls string = 'required'

var tlsEnabled = postgresqlTls == 'required'
var validatedAppName = tlsEnabled && empty(trim(postgresqlCaCertificate))
  ? fail('postgresqlCaCertificate is required when postgresqlTls is required.')
  : 'demo-${environmentName}'

// Environment name derived from the Environment ID, used to keep resource names
// unique per environment (e.g. dev/test/prod) within the same resource group.
var environmentName = last(split(environment, '/'))
var postgresqlCaName = 'postgresql-ca-${environmentName}'

resource demoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: validatedAppName
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
        env: tlsEnabled ? {
          RADIUS_DEMO_POSTGRESQL_TLS: {
            value: 'verify-full'
          }
          RADIUS_DEMO_POSTGRESQL_CA_FILE: {
            value: '/etc/postgresql-ca/ca.crt'
          }
        } : {
          PGSSLMODE: {
            value: 'disable'
          }
        }
        ...(tlsEnabled ? {
          volumeMounts: [
            {
              volumeName: 'postgresql-ca'
              mountPath: '/etc/postgresql-ca'
            }
          ]
        } : {})
        ports: {
          web: {
            containerPort: 3000
          }
        }
      }
    }
    ...(tlsEnabled ? {
      volumes: {
        'postgresql-ca': {
          secretName: postgresqlCaName
        }
      }
    } : {})
    connections: {
      postgresql: {
        source: postgresql.id
      }
      postgresqlCredentials: {
        source: postgresqlCredentials.id
      }
    }
  }
  // Order any CA Recipe instance before mounting its public certificate.
  dependsOn: [
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
    tls: postgresqlTls
  }
}

// Zero copies avoid dependencies on conditionally skipped resources.
resource postgresqlCa 'Radius.Security/secrets@2025-08-01-preview' = [for caName in (tlsEnabled ? [postgresqlCaName] : []): {
  name: caName
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
}]

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
