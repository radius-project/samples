extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

// v1.18.1 resolves to the pinned source revision dae05f49a25a28367407da0cf253fb0b7d831f8c.
param buildSource string = 'git::https://github.com/warpstreamlabs/bento.git?ref=refs/tags/v1.18.1'

var serviceBusConnectionPlaceholder = join(['$', '{SERVICE_BUS_CONNECTION_STRING}'], '')
var consumerConfigText = join([
  'http:'
  '  enabled: true'
  'input:'
  '  azure_service_bus_queue:'
  '    connection_string: ${serviceBusConnectionPlaceholder}'
  '    queue: jobs'
  '    max_in_flight: 1'
  '    auto_ack: false'
  '    renew_lock: true'
  'output:'
  '  http_server:'
  '    path: /get'
], '\n')

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'bento'
  properties: {
    environment: environment
  }
}

resource serviceBusSchemaSecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'service-bus-schema-credentials'
  properties: {
    environment: environment
    application: app.id
    data: {
      password: {
        #disable-next-line use-secure-value-for-secure-inputs
        value: 'unused-by-azure-service-bus-recipe'
      }
    }
  }
}

resource serviceBus 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'sb'
  // Keep the payload compatible with both published schema revisions: the Azure
  // recipe uses managed secrets, while the newer built-in schema requires password.
  properties: any({
    environment: environment
    application: app.id
    queue: 'jobs'
    password: serviceBusSchemaSecret.id
  })
}

resource image 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'img'
  properties: {
    environment: environment
    application: app.id
    tag: 'dae05f49a25a'
    build: {
      source: buildSource
      dockerfile: 'resources/docker/Dockerfile'
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource consumerConfig 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'consumer-config'
  properties: {
    environment: environment
    application: app.id
    data: {
      'consumer.yaml': {
        #disable-next-line use-secure-value-for-secure-inputs
        value: consumerConfigText
      }
    }
  }
}

resource producer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'prod'
  properties: {
    environment: environment
    application: app.id
    containers: {
      producer: {
        image: image.properties.imageReference
        // Bento's AMQP output needs separate SASL fields, so split the managed connection string at startup.
        command: [
          '/bin/sh'
          '-c'
        ]
        args: [
          '''
set -eu
KEY_NAME=$(printf '%s\n' "$SERVICE_BUS_CONNECTION_STRING" | tr ';' '\n' | sed -n 's/^SharedAccessKeyName=//p')
KEY=$(printf '%s\n' "$SERVICE_BUS_CONNECTION_STRING" | tr ';' '\n' | sed -n 's/^SharedAccessKey=//p')
test -n "$KEY_NAME"
test -n "$KEY"
cat > /tmp/producer.yaml <<EOF
http:
  enabled: true
input:
  http_server:
    path: /post
output:
  amqp_1:
    urls:
      - amqps://$SERVICE_BUS_HOST.servicebus.windows.net
    target_address: jobs
    max_in_flight: 1
    sasl:
      mechanism: plain
      user: $KEY_NAME
      password: $KEY
EOF
exec /bento -c /tmp/producer.yaml
'''
        ]
        ports: {
          http: {
            containerPort: 4195
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/ready'
            port: 4195
          }
        }
        env: {
          SERVICE_BUS_HOST: {
            value: serviceBus.properties.host
          }
          SERVICE_BUS_CONNECTION_STRING: {
            valueFrom: {
              secretKeyRef: {
                secretName: any(serviceBus.properties).secrets.name
                key: 'connectionString'
              }
            }
          }
        }
      }
    }
    connections: {
      servicebus: {
        source: serviceBus.id
      }
    }
  }
}

resource consumer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'cons'
  properties: {
    environment: environment
    application: app.id
    containers: {
      consumer: {
        image: image.properties.imageReference
        args: [
          '-c'
          '/etc/bento/consumer.yaml'
        ]
        ports: {
          http: {
            containerPort: 4195
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/ready'
            port: 4195
          }
        }
        env: {
          SERVICE_BUS_CONNECTION_STRING: {
            valueFrom: {
              secretKeyRef: {
                secretName: any(serviceBus.properties).secrets.name
                key: 'connectionString'
              }
            }
          }
        }
        volumeMounts: [
          {
            volumeName: 'config'
            mountPath: '/etc/bento'
          }
        ]
      }
    }
    volumes: {
      config: {
        secretName: consumerConfig.name
      }
    }
    connections: {
      servicebus: {
        source: serviceBus.id
      }
    }
  }
}
