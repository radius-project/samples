extension radius

@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'llm-azure-app-test'
  properties: {
    environment: environment
  }
}

resource model 'Radius.AI/models@2025-08-01-preview' = {
  name: 'model'
  properties: {
    environment: environment
    application: app.id
    model: 'gpt-5-mini'
  }
}

resource litellmImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'litellm-image'
  properties: {
    environment: environment
    application: app.id
    tag: 'v1.91.0'
    build: {
      source: 'git::https://github.com/BerriAI/litellm.git//?ref=v1.91.0'
    }
  }
}

resource litellmctr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'litellmctr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      litellm: {
        image: litellmImage.properties.imageReference
        command: [
          '/bin/sh'
          '-c'
          '''
set -eu
cat > /tmp/litellm.config.yaml <<'EOF'
model_list:
  - model_name: chat
    litellm_params:
      model: azure/chat
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY
      api_version: os.environ/AZURE_API_VERSION
EOF
exec litellm --config /tmp/litellm.config.yaml --host 0.0.0.0 --port 4000
'''
        ]
        ports: {
          web: {
            containerPort: 4000
          }
        }
        env: {
          AZURE_API_BASE: {
            value: model.properties.endpoint
          }
          AZURE_API_KEY: {
            valueFrom: {
              secretKeyRef: {
                secretName: model.properties.secrets.name
                key: 'apiKey'
              }
            }
          }
          AZURE_API_VERSION: {
            value: '2025-04-01-preview'
          }
          LITELLM_MASTER_KEY: {
            value: 'sk-radius-verify'
          }
        }
      }
    }
    connections: {
      model: {
        source: model.id
      }
    }
  }
}
