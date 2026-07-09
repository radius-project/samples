extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'rabbitmq-azure-app-test'
  properties: {
    environment: environment
  }
}

resource bentoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'bento-image'
  properties: {
    environment: environment
    application: app.id
    tag: 'v1.18.1'
    build: {
      source: 'git::https://github.com/warpstreamlabs/bento.git//?ref=v1.18.1'
      dockerfile: 'resources/docker/Dockerfile'
    }
  }
}

resource queue 'Radius.Messaging/rabbitMQ@2025-08-01-preview' = {
  name: 'rabbitmq'
  properties: {
    environment: environment
    application: app.id
    queue: 'jobs'
  }
}

resource bentoctr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'bentoctr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      producer: {
        image: bentoImage.properties.imageReference
        env: {
          RABBITMQ_HOST: {
            value: queue.properties.host
          }
          RABBITMQ_CONNECTIONSTRING: {
            valueFrom: {
              secretKeyRef: {
                secretName: queue.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
        command: [
          '/bin/sh'
          '-c'
          '''
set -eu
NS="$RABBITMQ_HOST"
KEY=$(printf '%s' "$RABBITMQ_CONNECTIONSTRING" | sed -n 's/.*SharedAccessKey=//p')
cat > /tmp/producer.yaml <<EOF
input:
  generate:
    count: 0
    interval: 5s
    mapping: 'root = {"message":"radius-bento","timestamp":now()}'
output:
  amqp_1:
    url: amqps://$NS.servicebus.windows.net
    target_address: jobs
    sasl:
      mechanism: plain
      user: RootManageSharedAccessKey
      password: "$KEY"
EOF
exec /bento -c /tmp/producer.yaml
'''
        ]
      }
      consumer: {
        image: bentoImage.properties.imageReference
        env: {
          RABBITMQ_HOST: {
            value: queue.properties.host
          }
          RABBITMQ_CONNECTIONSTRING: {
            valueFrom: {
              secretKeyRef: {
                secretName: queue.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
        }
        command: [
          '/bin/sh'
          '-c'
          '''
set -eu
NS="$RABBITMQ_HOST"
KEY=$(printf '%s' "$RABBITMQ_CONNECTIONSTRING" | sed -n 's/.*SharedAccessKey=//p')
cat > /tmp/consumer.yaml <<EOF
input:
  amqp_1:
    url: amqps://$NS.servicebus.windows.net
    source_address: jobs
    azure_renew_lock: true
    sasl:
      mechanism: plain
      user: RootManageSharedAccessKey
      password: "$KEY"
output:
  stdout: {}
EOF
exec /bento -c /tmp/consumer.yaml
'''
        ]
      }
    }
    connections: {
      rabbitmq: {
        source: queue.id
      }
    }
  }
}
