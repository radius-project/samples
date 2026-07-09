extension radius
@description('The ID of your Radius Environment. Set automatically by the rad CLI.')
param environment string

resource app 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'storage-azure-app-test'
  properties: {
    environment: environment
  }
}

resource sftpgoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'sftpgo-image'
  properties: {
    environment: environment
    application: app.id

    tag: 'v2.7.4'
    build: {
      source: 'git::https://github.com/drakkan/sftpgo.git//?ref=v2.7.4'
    }
  }
}

resource store 'Radius.Storage/objectStorage@2025-08-01-preview' = {
  name: 'store'
  properties: {
    environment: environment
    application: app.id

    containerName: 'data'
  }
}

resource sftpgoctr 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'sftpgoctr'
  properties: {
    environment: environment
    application: app.id
    containers: {
      sftpgo: {
        image: sftpgoImage.properties.imageReference

        command: [
          '/bin/sh'
          '-c'
          '''
set -eu
cat > /var/lib/sftpgo/init.json <<EOF
{"admins":[{"username":"admin","password":"radius-verify-Admin1!","status":1,"permissions":["*"]}],"users":[{"username":"radius","password":"radius-verify-Pass1!","status":1,"permissions":{"/":["*"]},"home_dir":"/srv/sftpgo/data/radius","filesystem":{"provider":3,"azblobconfig":{"container":"$AZ_CONTAINER","account_name":"$AZ_ACCOUNT","account_key":{"status":"Plain","payload":"$AZ_KEY"}}}}]}
EOF
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

          AZ_ACCOUNT: {
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
      }
    }

    connections: {
      store: {
        source: store.id
      }
    }
  }
}
