extension radius

param environment string

@secure()
param postgresPassword string

var images = loadJsonContent('images.lock.json').images
var postgresUsername = 'myadmin'

resource votingApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'example-voting-app'
  properties: {
    environment: environment
  }
}

resource voteContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'vote'
  properties: {
    environment: environment
    application: votingApp.id
    containers: {
      vote: {
        image: images.vote
        ports: {
          web: {
            containerPort: 80
          }
        }
        env: {
          REDIS_HOST: {
            value: 'localhost'
          }
          REDIS_PORT: {
            value: '6379'
          }
        }
      }
      redis: {
        image: images.redis
      }
      worker: {
        image: images.worker
        env: {
          POSTGRES_DB: {
            value: 'votes'
          }
          POSTGRES_HOST: {
            value: postgresDb.properties.host
          }
          POSTGRES_PASSWORD: {
            value: postgresPassword
          }
          POSTGRES_PORT: {
            value: '5432'
          }
          POSTGRES_SSLMODE: {
            value: 'prefer'
          }
          POSTGRES_USER: {
            value: postgresUsername
          }
          REDIS_HOST: {
            value: 'localhost'
          }
          REDIS_PORT: {
            value: '6379'
          }
        }
      }
    }
    connections: {
      postgresdb: {
        source: postgresDb.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource resultContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'result'
  properties: {
    environment: environment
    application: votingApp.id
    containers: {
      result: {
        image: images.result
        ports: {
          web: {
            containerPort: 80
          }
        }
        env: {
          PORT: {
            value: '80'
          }
          POSTGRES_DB: {
            value: 'votes'
          }
          POSTGRES_HOST: {
            value: postgresDb.properties.host
          }
          POSTGRES_PASSWORD: {
            value: postgresPassword
          }
          POSTGRES_PORT: {
            value: '5432'
          }
          POSTGRES_SSLMODE: {
            value: 'prefer'
          }
          POSTGRES_USER: {
            value: postgresUsername
          }
        }
      }
    }
    connections: {
      postgresdb: {
        source: postgresDb.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource postgresDb 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'db'
  properties: {
    environment: environment
    application: votingApp.id
    username: postgresUsername
    password: postgresPassword
    database: 'votes'
    size: 'S'
  }
}
