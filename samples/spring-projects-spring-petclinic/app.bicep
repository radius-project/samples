extension radius

@description('The ID of the Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('PostgreSQL admin password for the petclinic database. Radius encrypts it and injects it into the recipe and the application secret.')
@secure()
param password string

@description('Build context for the Spring PetClinic image. Defaults to the source directory published alongside this sample.')
param source string = 'git::https://github.com/radius-project/samples.git//samples/spring-projects-spring-petclinic/src?ref=edge'

@description('Optional single target platform for the image build (e.g. `linux/amd64`). Empty builds the default multi-architecture image.')
param buildPlatform string = ''

resource springPetclinicApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'spring-petclinic'
  properties: {
    environment: environment
  }
}

resource database 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'postgres'
  properties: {
    environment: environment
    application: springPetclinicApp.id
    size: 'S'
    database: 'petclinic'
    username: 'petclinic'
    password: password
  }
}

resource dbSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'dbsecret'
  properties: {
    environment: environment
    application: springPetclinicApp.id
    data: {
      POSTGRES_PASSWORD: {
        value: password
      }
    }
  }
}

resource petclinicImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'spring-petclinic-image'
  properties: {
    environment: environment
    application: springPetclinicApp.id
    tag: '51045d1648dad955df586150c1a1a6e22ef400c2'
    build: {
      source: source
      platforms: empty(buildPlatform) ? [
        'linux/amd64'
        'linux/arm64'
      ] : [
        buildPlatform
      ]
    }
  }
}

resource springPetclinicContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'spring-petclinic'
  properties: {
    environment: environment
    application: springPetclinicApp.id
    containers: {
      petclinic: {
        image: petclinicImage.properties.imageReference
        ports: {
          web: {
            containerPort: 8080
          }
        }
        env: {
          SPRING_PROFILES_ACTIVE: {
            value: 'postgres'
          }
          SPRING_APPLICATION_JSON: {
            value: '{"management.endpoint.health.probes.add-additional-paths":true}'
          }
          POSTGRES_URL: {
            value: 'jdbc:postgresql://${database.properties.host}:5432/petclinic?sslmode=require'
          }
          POSTGRES_USER: {
            value: 'petclinic'
          }
          POSTGRES_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'POSTGRES_PASSWORD'
              }
            }
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/readyz'
            port: 8080
          }
          initialDelaySeconds: 15
        }
        livenessProbe: {
          httpGet: {
            path: '/livez'
            port: 8080
          }
          initialDelaySeconds: 30
        }
      }
    }
    connections: {
      postgresdb: {
        source: database.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource springPetclinicRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'spring-petclinic'
  properties: {
    environment: environment
    application: springPetclinicApp.id
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: springPetclinicContainer.id
          containerName: 'petclinic'
          containerPort: 8080
        }
      }
    ]
  }
}
