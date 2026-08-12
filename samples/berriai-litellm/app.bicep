extension radius

param environment string

// v1.91.0 resolves to the pinned source revision 0519dbf25b290dd3a646bf40dc93d40ae36901aa.
param buildSource string = 'git::https://github.com/BerriAI/litellm.git?ref=refs/tags/v1.91.0'

@secure()
param litellmMasterKey string

param azureApiVersion string = '2025-04-01-preview'

resource litellmApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'litellm'
  properties: {
    environment: environment
  }
}

resource model 'Radius.AI/models@2025-08-01-preview' = {
  name: 'model'
  properties: {
    environment: environment
    application: litellmApp.id
    model: 'gpt-5-mini'
  }
}

resource litellmImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'litellm-image'
  properties: {
    environment: environment
    application: litellmApp.id
    tag: '0519dbf25b29'
    build: {
      source: buildSource
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource litellmContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'litellm'
  properties: {
    environment: environment
    application: litellmApp.id
    containers: {
      litellm: {
        image: litellmImage.properties.imageReference
        args: [
          '--model'
          'azure/chat'
          '--alias'
          'chat'
          '--api_version'
          azureApiVersion
          '--host'
          '0.0.0.0'
          '--port'
          '4000'
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
            value: azureApiVersion
          }
          LITELLM_MASTER_KEY: {
            value: litellmMasterKey
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/health/liveliness'
            port: 4000
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
