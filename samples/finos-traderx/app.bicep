extension radius

@description('The ID of the Radius Environment. Set automatically by the rad CLI.')
param environment string

@description('PostgreSQL admin password for the TraderX database. Radius encrypts it and injects it into the recipe and the application secret.')
@secure()
param password string

@description('Externally reachable URL for the TraderX edge proxy. Must be the URL clients use to reach the edge route; used for CORS allow-listing across the services.')
param publicUrl string

@description('Image tag applied to the TraderX service images. Defaults to the pinned upstream commit that the images are built from.')
param imageTag string = 'afe174d8feaf0a059b68423f3ff2db570eb6d843'

@description('Base go-getter source for the upstream FINOS TraderX repository. Each service image builds from a subdirectory of this repository at `imageTag`.')
param sourceRepo string = 'git::https://github.com/finos/traderX.git'

@description('Build context for the sample-owned schema loader image. Defaults to the source directory published alongside this sample.')
param schemaLoaderSource string = 'git::https://github.com/radius-project/samples.git//samples/finos-traderx/src/schema-loader?ref=edge'

@description('Optional single target platform for the image builds (e.g. `linux/amd64`). Empty builds the default multi-architecture images.')
param buildPlatform string = ''

var databaseUsername = 'traderx'
var databaseName = 'traderx'

var platforms = empty(buildPlatform) ? [
  'linux/amd64'
  'linux/arm64'
] : [
  buildPlatform
]

resource traderxApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'traderx'
  properties: {
    environment: environment
  }
}

resource database 'Radius.Data/postgreSqlDatabases@2025-08-01-preview' = {
  name: 'database'
  properties: {
    environment: environment
    application: traderxApp.id
    size: 'S'
    database: databaseName
    username: databaseUsername
    password: password
  }
}

resource dbSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'dbsecret'
  properties: {
    environment: environment
    application: traderxApp.id
    data: {
      DATABASE_PASSWORD: {
        value: password
      }
    }
  }
}

resource referenceDataImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'reference-data-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//reference-data?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource peopleImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'people-service-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//people-service?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource accountImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'account-service-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//account-service?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource positionImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'position-service-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//position-service?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource tradeProcessorImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'trade-processor-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//trade-processor?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource tradeServiceImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'trade-service-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//trade-service?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource pricePublisherImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'price-publisher-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//price-publisher?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource orderMatcherImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'order-matcher-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//order-matcher?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource webFrontendImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'web-front-end-angular-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: '${sourceRepo}//web-front-end/angular?ref=${imageTag}'
      dockerfile: 'Dockerfile.compose'
      platforms: platforms
    }
  }
}

resource schemaLoaderImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'schema-loader-image'
  properties: {
    environment: environment
    application: traderxApp.id
    tag: imageTag
    build: {
      source: schemaLoaderSource
      dockerfile: 'Dockerfile'
      platforms: platforms
    }
  }
}

resource schemaLoaderContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'schema-loader'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      schemaLoader: {
        image: schemaLoaderImage.properties.imageReference
        env: {
          PGHOST: {
            value: database.properties.host
          }
          PGPORT: {
            value: '5432'
          }
          PGDATABASE: {
            value: databaseName
          }
          PGUSER: {
            value: databaseUsername
          }
          PGPASSWORD: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'DATABASE_PASSWORD'
              }
            }
          }
          PGSSLMODE: {
            value: 'require'
          }
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

resource natsContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'nats-broker'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      nats: {
        image: 'nats:2.14-alpine'
        command: [
          '/bin/sh'
          '-c'
        ]
        args: [
          '''
cat > /tmp/nats.conf <<'EOF'
port: 4222
http: 8222

websocket {
  port: 8081
  no_tls: true
}
EOF
exec nats-server -c /tmp/nats.conf
'''
        ]
        ports: {
          client: {
            containerPort: 4222
          }
          monitor: {
            containerPort: 8222
          }
          websocket: {
            containerPort: 8081
          }
        }
      }
    }
  }
}

resource referenceDataContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'reference-data'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      referenceData: {
        image: referenceDataImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18085
          }
        }
        env: {
          REFERENCE_DATA_SERVICE_PORT: {
            value: '18085'
          }
          CORS_ALLOWED_ORIGINS: {
            value: publicUrl
          }
          REFERENCE_DATA_SUPPORTED_TICKERS: {
            value: 'AAPL,MSFT,AMZN,GOOGL,META,NVDA,TSLA,IBM,BAC,C,JPM,GS,MS,UBS,DB,COF,DFS,FNMA,FIS,FNF'
          }
        }
      }
    }
  }
}

resource peopleContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'people-service'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      people: {
        image: peopleImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18089
          }
        }
        env: {
          PEOPLE_SERVICE_PORT: {
            value: '18089'
          }
          CORS_ALLOWED_ORIGINS: {
            value: publicUrl
          }
        }
      }
    }
  }
}

resource accountContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'account-service'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      account: {
        image: accountImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18088
          }
        }
        env: {
          ACCOUNT_SERVICE_PORT: {
            value: '18088'
          }
          SPRING_DATASOURCE_URL: {
            value: 'jdbc:postgresql://${database.properties.host}:5432/${databaseName}?sslmode=require'
          }
          DATABASE_PG_HOST: {
            value: database.properties.host
          }
          DATABASE_PG_PORT: {
            value: '5432'
          }
          DATABASE_NAME: {
            value: databaseName
          }
          DATABASE_DBUSER: {
            value: databaseUsername
          }
          DATABASE_DBPASS: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'DATABASE_PASSWORD'
              }
            }
          }
          PEOPLE_SERVICE_HOST: {
            value: 'people-service'
          }
          CORS_ALLOWED_ORIGINS: {
            value: publicUrl
          }
        }
      }
    }
    connections: {
      postgresdb: {
        source: database.id
        disableDefaultEnvVars: true
      }
      peopleService: {
        source: peopleContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource positionContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'position-service'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      position: {
        image: positionImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18090
          }
        }
        env: {
          POSITION_SERVICE_PORT: {
            value: '18090'
          }
          SPRING_DATASOURCE_URL: {
            value: 'jdbc:postgresql://${database.properties.host}:5432/${databaseName}?sslmode=require'
          }
          DATABASE_PG_HOST: {
            value: database.properties.host
          }
          DATABASE_PG_PORT: {
            value: '5432'
          }
          DATABASE_NAME: {
            value: databaseName
          }
          DATABASE_DBUSER: {
            value: databaseUsername
          }
          DATABASE_DBPASS: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'DATABASE_PASSWORD'
              }
            }
          }
          CORS_ALLOWED_ORIGINS: {
            value: publicUrl
          }
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

resource tradeProcessorContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'trade-processor'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      tradeProcessor: {
        image: tradeProcessorImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18091
          }
        }
        env: {
          TRADE_PROCESSOR_SERVICE_PORT: {
            value: '18091'
          }
          SPRING_DATASOURCE_URL: {
            value: 'jdbc:postgresql://${database.properties.host}:5432/${databaseName}?sslmode=require'
          }
          DATABASE_PG_HOST: {
            value: database.properties.host
          }
          DATABASE_PG_PORT: {
            value: '5432'
          }
          DATABASE_NAME: {
            value: databaseName
          }
          DATABASE_DBUSER: {
            value: databaseUsername
          }
          DATABASE_DBPASS: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'DATABASE_PASSWORD'
              }
            }
          }
          NATS_BROKER_HOST: {
            value: 'nats-broker'
          }
          CORS_ALLOWED_ORIGINS: {
            value: publicUrl
          }
        }
      }
    }
    connections: {
      postgresdb: {
        source: database.id
        disableDefaultEnvVars: true
      }
      nats: {
        source: natsContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource tradeServiceContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'trade-service'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      tradeService: {
        image: tradeServiceImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18092
          }
        }
        env: {
          TRADING_SERVICE_PORT: {
            value: '18092'
          }
          ACCOUNT_SERVICE_HOST: {
            value: 'account-service'
          }
          REFERENCE_DATA_HOST: {
            value: 'reference-data'
          }
          PEOPLE_SERVICE_HOST: {
            value: 'people-service'
          }
          NATS_BROKER_HOST: {
            value: 'nats-broker'
          }
          PRICE_SERVICE_HOST: {
            value: 'price-publisher'
          }
          CORS_ALLOWED_ORIGINS: {
            value: publicUrl
          }
        }
      }
    }
    connections: {
      accountService: {
        source: accountContainer.id
        disableDefaultEnvVars: true
      }
      referenceData: {
        source: referenceDataContainer.id
        disableDefaultEnvVars: true
      }
      peopleService: {
        source: peopleContainer.id
        disableDefaultEnvVars: true
      }
      nats: {
        source: natsContainer.id
        disableDefaultEnvVars: true
      }
      pricePublisher: {
        source: pricePublisherContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource pricePublisherContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'price-publisher'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      pricePublisher: {
        image: pricePublisherImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18100
          }
        }
        env: {
          PRICE_PUBLISHER_PORT: {
            value: '18100'
          }
          NATS_BROKER_HOST: {
            value: 'nats-broker'
          }
          PRICE_BOOTSTRAP_MODE: {
            value: 'snapshot'
          }
          PRICE_TICKERS: {
            value: 'AAPL,MSFT,AMZN,GOOGL,META,NVDA,TSLA,IBM,BAC,C,JPM,GS,MS,UBS,DB,COF,DFS,FNMA,FIS,FNF'
          }
        }
      }
    }
    connections: {
      nats: {
        source: natsContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource orderMatcherContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'order-matcher'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      orderMatcher: {
        image: orderMatcherImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18110
          }
        }
        env: {
          ORDER_MATCHER_PORT: {
            value: '18110'
          }
          SPRING_DATASOURCE_URL: {
            value: 'jdbc:postgresql://${database.properties.host}:5432/${databaseName}?sslmode=require'
          }
          DATABASE_PG_HOST: {
            value: database.properties.host
          }
          DATABASE_PG_PORT: {
            value: '5432'
          }
          DATABASE_NAME: {
            value: databaseName
          }
          DATABASE_DBUSER: {
            value: databaseUsername
          }
          DATABASE_DBPASS: {
            valueFrom: {
              secretKeyRef: {
                secretName: dbSecret.name
                key: 'DATABASE_PASSWORD'
              }
            }
          }
          NATS_BROKER_HOST: {
            value: 'nats-broker'
          }
          CORS_ALLOWED_ORIGINS: {
            value: publicUrl
          }
          PRICE_SERVICE_URL: {
            value: 'http://price-publisher:18100'
          }
          TRADE_SERVICE_URL: {
            value: 'http://trade-service:18092/trade/'
          }
          ORDER_MATCHER_TICK_MS: {
            value: '1000'
          }
          ORDER_FILL_FULL_THRESHOLD: {
            value: '1000'
          }
        }
      }
    }
    connections: {
      postgresdb: {
        source: database.id
        disableDefaultEnvVars: true
      }
      nats: {
        source: natsContainer.id
        disableDefaultEnvVars: true
      }
      pricePublisher: {
        source: pricePublisherContainer.id
        disableDefaultEnvVars: true
      }
      tradeService: {
        source: tradeServiceContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource webFrontendContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'web-front-end-angular'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      webFrontend: {
        image: webFrontendImage.properties.imageReference
        ports: {
          web: {
            containerPort: 18093
          }
        }
        env: {
          WEB_SERVICE_PORT: {
            value: '18093'
          }
        }
      }
    }
  }
}

resource edgeContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'edge-proxy'
  properties: {
    environment: environment
    application: traderxApp.id
    containers: {
      edge: {
        image: 'nginx:1.27-alpine'
        command: [
          '/bin/sh'
          '-c'
        ]
        args: [
          '''
cat > /etc/nginx/conf.d/default.conf <<'EOF'
server {
  listen 8080;
  server_name _;

  location = /health {
    add_header Content-Type text/plain;
    return 200 "ok\n";
  }

  location /reference-data/ {
    proxy_pass http://reference-data:18085/;
  }

  location /people-service/ {
    proxy_set_header X-Forwarded-Prefix /people-service;
    proxy_pass http://people-service:18089/;
  }

  location /account-service/ {
    proxy_set_header X-Forwarded-Prefix /account-service;
    proxy_pass http://account-service:18088/;
  }

  location /position-service/ {
    proxy_set_header X-Forwarded-Prefix /position-service;
    proxy_pass http://position-service:18090/;
  }

  location /trade-service/ {
    proxy_set_header X-Forwarded-Prefix /trade-service;
    proxy_pass http://trade-service:18092/;
  }

  location /trade-processor/ {
    proxy_set_header X-Forwarded-Prefix /trade-processor;
    proxy_pass http://trade-processor:18091/;
  }

  location /price-publisher/ {
    proxy_set_header X-Forwarded-Prefix /price-publisher;
    proxy_pass http://price-publisher:18100/;
  }

  location /order-matcher/ {
    proxy_set_header X-Forwarded-Prefix /order-matcher;
    proxy_pass http://order-matcher:18110/;
  }

  location /nats-ws {
    proxy_pass http://nats-broker:8081;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $http_host;
  }

  location / {
    proxy_pass http://web-front-end-angular:18093/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}
EOF
exec nginx -g 'daemon off;'
'''
        ]
        ports: {
          web: {
            containerPort: 8080
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/health'
            port: 8080
          }
        }
      }
    }
    connections: {
      referenceData: {
        source: referenceDataContainer.id
        disableDefaultEnvVars: true
      }
      peopleService: {
        source: peopleContainer.id
        disableDefaultEnvVars: true
      }
      accountService: {
        source: accountContainer.id
        disableDefaultEnvVars: true
      }
      positionService: {
        source: positionContainer.id
        disableDefaultEnvVars: true
      }
      tradeProcessor: {
        source: tradeProcessorContainer.id
        disableDefaultEnvVars: true
      }
      tradeService: {
        source: tradeServiceContainer.id
        disableDefaultEnvVars: true
      }
      pricePublisher: {
        source: pricePublisherContainer.id
        disableDefaultEnvVars: true
      }
      orderMatcher: {
        source: orderMatcherContainer.id
        disableDefaultEnvVars: true
      }
      webFrontend: {
        source: webFrontendContainer.id
        disableDefaultEnvVars: true
      }
      nats: {
        source: natsContainer.id
        disableDefaultEnvVars: true
      }
    }
  }
}

resource traderxRoute 'Radius.Compute/routes@2025-08-01-preview' = {
  name: 'traderx'
  properties: {
    environment: environment
    application: traderxApp.id
    rules: [
      {
        matches: [
          {
            httpPath: '/'
          }
        ]
        destinationContainer: {
          resourceId: edgeContainer.id
          containerName: 'edge'
          containerPort: 8080
        }
      }
    ]
  }
}
