//MONGO
import kubernetes as kubernetes {
  kubeConfig: ''
  namespace: namespace
}

param namespace string = 'default'
param name string = 'mongo'

var port = 27017

//SS
resource statefulset 'apps/StatefulSet@v1' = {
  metadata: {
    name: name
    labels: {
      app: name
    }
  }
  spec: {
    replicas: 1
    serviceName: name
    selector: {
      matchLabels: {
        app: name
      }
    }
    template: {
      metadata: {
        labels: {
          app: name
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
              '--replSet=${name}'
              '--bind_ip_all'
            ]
            env: [
              {
                name: 'MONGO_INITDB_DATABASE'
                value: name
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
                value: 'app=${name}'
              }
              {
                name: 'KUBERNETES_MONGO_SERVICE_NAME'
                value: name
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
//SS
//SERVICE
resource service 'core/Service@v1' = {
  metadata: {
    name: name
    labels: {
      app: name
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
      app: name
    }
  }
}
//SERVICE

output host string = name
output port int = int(port)
output connectionString string = 'mongodb://${name}.${namespace}.svc.cluster.local:${port}/${name}?authSource=admin'
//MONGO

resource sa 'core/ServiceAccount@v1' = {
  metadata: {
    name: name
  }
}

resource crb 'rbac.authorization.k8s.io/ClusterRoleBinding@v1' = {
  metadata: {
    name: name
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
    name: name
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

resource secret 'core/Secret@v1' = {
  metadata: {
    name: name
    labels: {
      app: name
    }
  }
  stringData: {
    database: name
    connectionString: 'mongodb://${name}.${namespace}.svc.cluster.local:${port}/${name}?authSource=admin'
  }
}
