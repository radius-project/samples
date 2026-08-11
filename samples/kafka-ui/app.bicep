extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

var dollar = '$'

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'kafka-ui'
  properties: {
    environment: environment
  }
}

resource eventHubs 'Radius.Messaging/kafka@2025-08-01-preview' = {
  name: 'eh'
  properties: {
    environment: environment
    application: app.id
    topic: 'events'
  }
}

resource ui 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'ui'
  properties: {
    environment: environment
    application: app.id
    containers: {
      'kafka-ui': {
        image: 'ghcr.io/kafbat/kafka-ui@sha256:7cda86a33344160309fdb65146332e4da65db81a945614f2fe32e210803f6fd1'
        ports: {
          http: {
            containerPort: 8080
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/actuator/health'
            port: 8080
          }
        }
        env: {
          KAFKA_CLUSTERS_0_NAME: {
            value: 'event-hubs'
          }
          KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: {
            value: '${eventHubs.properties.host}.servicebus.windows.net:9093'
          }
          KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL: {
            value: 'SASL_SSL'
          }
          KAFKA_CLUSTERS_0_PROPERTIES_SASL_MECHANISM: {
            value: 'PLAIN'
          }
          EVENT_HUBS_CONNECTION_STRING: {
            valueFrom: {
              secretKeyRef: {
                secretName: eventHubs.properties.secrets.name
                key: 'connectionString'
              }
            }
          }
          KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG: {
            value: 'org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="${dollar}{EVENT_HUBS_CONNECTION_STRING}";'
          }
        }
      }
    }
    connections: {
      eventhubs: {
        source: eventHubs.id
      }
    }
  }
}
