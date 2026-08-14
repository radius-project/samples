extension radius

param environment string

param buildSource string = 'git::https://github.com/docker/getting-started-todo-app.git?ref=55680777bc46c59d3fe0ab9ff7e79ee947d0c757'

@secure()
param mysqlPassword string

var mysqlUsername = 'radadmin'
var mysqlDatabase = 'todos'

resource mysqlTodoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'mysql-todo'
  properties: {
    environment: environment
  }
}

resource mysql 'Radius.Data/mySqlDatabases@2025-08-01-preview' = {
  name: 'mysql'
  properties: {
    environment: environment
    application: mysqlTodoApp.id
    version: '8.0'
    database: mysqlDatabase
    username: mysqlUsername
    password: mysqlPassword
  }
}

resource mysqlTodoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'mysql-todo-image'
  properties: {
    environment: environment
    application: mysqlTodoApp.id
    build: {
      source: buildSource
      platforms: [
        'linux/amd64'
      ]
    }
  }
}

resource mysqlTodoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'mysql-todo'
  properties: {
    environment: environment
    application: mysqlTodoApp.id
    containers: {
      todo: {
        image: mysqlTodoImage.properties.imageReference
        // The pinned app has no TLS option, so preload mysql2 to require certificate-verified TLS.
        command: [
          '/bin/sh'
          '-c'
        ]
        args: [
          '''
set -eu
cat > /tmp/mysql-tls.js <<'EOF'
const mysql = require('/usr/local/app/node_modules/mysql2');
const createPool = mysql.createPool;
mysql.createPool = (options) => {
    const pool = createPool({
        ...options,
        ssl: { rejectUnauthorized: true },
    });
    pool.on('connection', (connection) => {
        connection.query("SHOW STATUS LIKE 'Ssl_cipher'", (error, rows) => {
            if (error) {
                console.error(`MySQL TLS verification failed: ${error.message}`);
                process.exit(1);
            }
            const cipher = rows?.[0]?.Value;
            if (!cipher) {
                console.error('MySQL TLS verification failed: no negotiated cipher');
                process.exit(1);
            }
            console.log(`MySQL TLS verified: ${cipher}`);
        });
    });
    return pool;
};
EOF
exec node --require /tmp/mysql-tls.js src/index.js
'''
        ]
        ports: {
          web: {
            containerPort: 3000
          }
        }
        env: {
          MYSQL_HOST: {
            value: mysql.properties.host
          }
          MYSQL_DB: {
            value: mysqlDatabase
          }
          MYSQL_USER: {
            value: mysqlUsername
          }
          MYSQL_PASSWORD: {
            value: mysqlPassword
          }
        }
        readinessProbe: {
          httpGet: {
            path: '/api/greeting'
            port: 3000
          }
        }
      }
    }
    connections: {
      mysqldb: {
        source: mysql.id
        disableDefaultEnvVars: true
      }
    }
  }
}
