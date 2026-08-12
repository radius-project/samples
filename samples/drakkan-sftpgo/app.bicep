extension radius

param environment string

param buildSource string = 'git::https://github.com/drakkan/sftpgo.git?ref=5c1286eaed6b45dbd4e3f651d9f596c5f3ccb3a6'

@secure()
param sftpgoAdminPassword string

@secure()
param sftpgoUserPassword string

resource sftpgoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'sftpgo'
  properties: {
    environment: environment
  }
}

resource store 'Radius.Storage/objectStorage@2025-08-01-preview' = {
  name: 'store'
  properties: {
    environment: environment
    application: sftpgoApp.id
    containerName: 'data'
  }
}

resource sftpgoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'sftpgo-image'
  properties: {
    environment: environment
    application: sftpgoApp.id
    tag: '5c1286eaed6b'
    build: {
      source: buildSource
      dockerfile: 'Dockerfile.alpine'
      platforms: [
        'linux/amd64'
      ]
      args: {
        COMMIT_SHA: '5c1286eaed6b45dbd4e3f651d9f596c5f3ccb3a6'
        GOPROXY: 'https://proxy.golang.org|direct'
        INSTALL_OPTIONAL_PACKAGES: 'true'
      }
    }
  }
}

resource sftpgoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'sftpgo'
  properties: {
    environment: environment
    application: sftpgoApp.id
    containers: {
      sftpgo: {
        image: sftpgoImage.properties.imageReference
        // SFTPGo requires Blob credentials inside its restore document, so render it from the managed secret at startup.
        command: [
          '/bin/sh'
          '-c'
          '''
set -eu
jq -n \
  --arg adminPassword "$SFTPGO_ADMIN_PASSWORD" \
  --arg userPassword "$SFTPGO_USER_PASSWORD" \
  --arg accountName "$AZ_ACCOUNT_NAME" \
  --arg accountKey "$AZ_KEY" \
  --arg container "$AZ_CONTAINER" \
  '{
    version: 17,
    admins: [{
      username: "admin",
      password: $adminPassword,
      status: 1,
      permissions: ["*"]
    }],
    users: [{
      username: "radius",
      password: $userPassword,
      status: 1,
      permissions: {"/": ["*"]},
      home_dir: "/srv/sftpgo/data/radius",
      filesystem: {
        provider: 3,
        azblobconfig: {
          container: $container,
          account_name: $accountName,
          account_key: {
            status: "Plain",
            payload: $accountKey
          }
        }
      }
    }]
  }' > /var/lib/sftpgo/init.json
exec sftpgo serve
'''
        ]
        ports: {
          sftp: {
            containerPort: 2022
          }
          http: {
            containerPort: 8080
          }
        }
        env: {
          SFTPGO_DATA_PROVIDER__DRIVER: {
            value: 'memory'
          }
          SFTPGO_LOADDATA_FROM: {
            value: '/var/lib/sftpgo/init.json'
          }
          SFTPGO_LOG_FILE_PATH: {
            value: ''
          }
          SFTPGO_ADMIN_PASSWORD: {
            value: sftpgoAdminPassword
          }
          SFTPGO_USER_PASSWORD: {
            value: sftpgoUserPassword
          }
          AZ_ACCOUNT_NAME: {
            value: store.properties.accountName
          }
          AZ_KEY: {
            valueFrom: {
              secretKeyRef: {
                secretName: store.properties.secrets.name
                key: 'accountKey'
              }
            }
          }
          AZ_CONTAINER: {
            value: store.properties.containerName
          }
        }
        readinessProbe: {
          tcpSocket: {
            port: 2022
          }
        }
      }
    }
    connections: {
      store: {
        source: store.id
      }
    }
  }
}
