# Radius Demo App

This application is used to demonstrate Radius basics as part of our 'first application' tutorial.

Visit https://radapp.io to try it out.

## Build the container image with a configured npm registry

To use the npm registry configured on the host, pass it to the container build:

```sh
docker build \
  --build-arg NPM_CONFIG_REGISTRY="$(npm config get registry)" \
  --tag radius-demo:local \
  samples/demo
```

## PostgreSQL variant

`app-postgresql.bicep` uses the Kubernetes Container Recipe's direct Secret connection support to project the database password as `CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD`. This requires Radius 0.61.0 or later, or a current edge installation.

The demo image prefers that variable and retains `CONNECTION_POSTGRESQL_PASSWORD` as a compatibility fallback for older or mixed installations whose PostgreSQL Recipe still supplies the password. If both variables are set to different values, the demo logs a warning and uses `CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD`. Azure ACI does not project direct Secret connections, so this new password path is Kubernetes-only; its existing connection behavior is unchanged.

### Kubernetes PostgreSQL TLS

This template uses the existing Node.js PostgreSQL client's `PGSSLMODE=verify-full` and `NODE_EXTRA_CA_CERTS` settings to require encrypted connections and verify the server certificate and hostname. It uses TLS even if the database policy permits plaintext; it never falls back after a trust error. No demo image rebuild is needed for this configuration.

The demo's generated connection URI has no SSL query parameters. Keep it that way: URI SSL options take precedence over `PGSSLMODE` and can disable verification or encryption.

Before generating certificates, set the Environment name (the last segment of its ID) and its actual Kubernetes namespace. The namespace is not necessarily the same as the Environment name:

```bash
environment=default
namespace=default # Replace with the namespace shown by rad env show.
database="postgresql-$environment"
```

Obtain a server certificate with a DNS subject alternative name matching `postgresql-<environment>.<namespace>.svc.cluster.local` from your operator. For an isolated development cluster, follow the [PostgreSQL Recipe TLS guide's development CA example](https://github.com/radius-project/resource-types-contrib/blob/main/Data/postgreSqlDatabases/README.md#kubernetes-tls) using the variables above, not its generic `database=postgresql` or namespace assignments. Run the certificate-generation steps, including `umask`, the `hostname` assignment, the `printf` command that prepares the SAN extension file, and the `openssl` commands. Skip the guide's `kubectl create secret` command.

Once `server.crt`, `server.key`, and `ca.crt` are available, create both operator-owned Secrets here:

```bash
kubectl create secret tls "postgresql-$environment-tls" -n "$namespace" \
  --cert=server.crt --key=server.key
kubectl create secret generic "postgresql-$environment-ca" -n "$namespace" \
  --from-file=ca.crt=ca.crt
```

The TLS Secret holds the leaf-first server certificate chain and matching unencrypted private key. The CA Secret contains only the public root CA; the client mounts it at `/etc/postgresql-ca/ca.crt`. Never distribute the server key or CA private key to the demo. See the [PostgreSQL Recipe TLS guide](https://github.com/radius-project/resource-types-contrib/blob/main/Data/postgreSqlDatabases/README.md#kubernetes-tls) for certificate creation, a development CA example, and artifact migration.

These instructions require a PostgreSQL Kubernetes Recipe with TLS support; older plaintext-only Recipes cannot serve this verified connection. The TLS Secret is required by the updated Recipes even when `tls` is optional. Coordinate the new sample configuration with the updated Recipe artifact rather than assuming a source merge updates a running server.

**Back up data before any database rollout:** the default PostgreSQL Recipes do not provision durable data volumes. Rotate the server Secret and explicitly restart the database Deployment to load it. If the public CA changes, update the CA Secret and restart the demo too, since Node loads additional CAs at process startup. Application deletion removes the authored password Secret, not these two operator-owned Secrets; delete them explicitly when no longer needed:

```bash
kubectl delete secret "postgresql-$environment-tls" "postgresql-$environment-ca" -n "$namespace"
```
