import radius as radius
import kubernetes as kubernetes {
  kubeConfig: ''
  namespace: namespace
}

@description('resource id of the radius environment')
param environment string

@description('namespace for kubernetes resources')
param namespace string = 'default'

@description('name of the database. used for kubernetes resources and radius connector')
param dbname string = 'tododb'

var port = 27017
var hostname = '${dbname}.${namespace}.svc.cluster.local'

resource db 'Applications.Connector/mongoDatabases@2022-03-15-privatepreview' = {
  name: dbname
  location: 'global'
  properties: {
    environment: environment
    host: hostname
    port: port
    secrets: {
      connectionString: 'mongodb://${hostname}:${port}/${dbname}?authSource=admin'
    }
  }
}

resource statefulset 'apps/StatefulSet@v1' = {
  metadata: {
    name: dbname
    labels: {
      app: dbname
    }
  }
  spec: {
    replicas: 1
    serviceName: dbname
    selector: {
      matchLabels: {
        app: dbname
      }
    }
    template: {
      metadata: {
        labels: {
          app: dbname
        }
      }
      spec: {
        serviceAccountName: sa.metadata.name
        automountServiceAccountToken: true
        terminationGracePeriodSeconds: 10
        containers: [
          {
            name: 'mongo'
            image: 'mongo:5'
            command: [
              'mongod'
              '--replSet=${dbname}'
              '--bind_ip_all'
            ]
            env: [
              {
                name: 'MONGO_INITDB_DATABASE'
                value: dbname
              }
            ]
            securityContext: {
              allowPrivilegeEscalation: false
            }
            ports: [
              {
                containerPort: port
              }
            ]
            volumeMounts: [
              {
                name: 'db-storage-claim'
                mountPath: '/data/db'
              }
            ]
          }
          {
            name: 'replset-sidecar'
            image: 'cvallance/mongo-k8s-sidecar'
            env: [
              {
                name: 'MONGO_SIDECAR_POD_LABELS'
                value: 'app=${dbname}'
              }
              {
                name: 'KUBERNETES_MONGO_SERVICE_NAME'
                value: dbname
              }
            ]
          }
        ]
      }
    }
    volumeClaimTemplates: [
      {
        metadata: {
          name: 'db-storage-claim'
        }
        spec: {
          accessModes: [ 'ReadWriteOnce' ]
          resources: {
            requests: {
              storage: '200Mi'
            }
          }
        }
      }
    ]
  }
}

resource service 'core/Service@v1' = {
  metadata: {
    name: dbname
    labels: {
      app: dbname
    }
  }
  spec: {
    clusterIP: 'None'
    ports: [
      {
        port: port
      }
    ]
    selector: {
      app: dbname
    }
  }
}

resource sa 'core/ServiceAccount@v1' = {
  metadata: {
    name: dbname
  }
}

resource crb 'rbac.authorization.k8s.io/ClusterRoleBinding@v1' = {
  metadata: {
    name: dbname
  }
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io'
    kind: 'ClusterRole'
    name: clusterrole.metadata.name
  }
  subjects: [
    {
      kind: 'ServiceAccount'
      name: sa.metadata.name
      namespace: sa.metadata.namespace
    }
  ]
}

resource clusterrole 'rbac.authorization.k8s.io/ClusterRole@v1' = {
  metadata: {
    name: dbname
  }
  rules: [
    {
      apiGroups: [
        ''
      ]
      resources: [
        'pods'
        'services'
        'endpoints'
      ]
      verbs: [
        'get'
        'list'
        'watch'
      ]
    }
  ]
}
