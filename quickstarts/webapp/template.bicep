resource app 'radius.dev/Application@v1alpha3' = {
  name: 'webapp'

  resource todoapplication 'Container' = {
    name: 'todoapp'
    properties: {
      container: {
        image: 'radius.azurecr.io/webapptutorial-todoapp'
        ports: {
          web: {
            containerPort: 3000
            provides: httpRoute.id
          }
        }
        env: {
          DBCONNECTION: db.connectionString()
        }
      }
      connections: {
        todoitems: {
          kind: 'mongo.com/MongoDB'
          source: db.id
        }
      }
    }
    dependsOn: [
      dbStarter
    ]
  }

  resource httpRoute 'HttpRoute' = {
    name: 'http-route'
  }

  resource db 'mongo.com.MongoDatabase' existing = {
    name: 'db'
  }

}

module dbStarter 'br:radius.azurecr.io/starters/mongo:latest' = {
  name: 'db-starter'
  params: {
    dbName: 'db'
    radiusApplication: app 
  }
}
