extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'kafka-azure-test'
  properties: {
    environment: environment
  }
}

resource kafkaBroker 'Radius.Messaging/kafka@2025-08-01-preview' = {
  name: 'kafka'
  properties: {
    environment: environment
    application: app.id
    topic: 'events'
  }
}

resource kafkauictr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'kafkauictr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      kafkaui: {
        image: 'ghcr.io/kafbat/kafka-ui:v1.5.0'
        ports: {
          web: {
            containerPort: 8080
          }
        }
        env: {
          KAFKA_CLUSTERS_0_NAME: {
            value: 'event-hubs'
          }

          KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: {
            value: '${kafkaBroker.properties.host}.servicebus.windows.net:9093'
          }
          KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL: {
            value: 'SASL_SSL'
          }
          KAFKA_CLUSTERS_0_PROPERTIES_SASL_MECHANISM: {
            value: 'PLAIN'
          }

          RAD_SECRET_CONNECTIONSTRING: {
            valueFrom: {
              secretKeyRef: {
                secretName: kafkaBroker.properties.secrets.name
                key: 'connectionString'
              }
            }
          }

          KAFKA_CLUSTERS_0_PROPERTIES_SASL_JAAS_CONFIG: {
            value: 'org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="$(RAD_SECRET_CONNECTIONSTRING)";'
          }
        }
      }
    }
    connections: {
      kafka: {
        source: kafkaBroker.id
      }
    }
  }
}
