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

### Explicit client TLS

When PostgreSQL is selected, a nonempty `CONNECTION_POSTGRESQL_PORT` must contain
only decimal digits and have a value from 1 to 65535. Leading zeros are accepted:
`05432` means 5432. Whitespace, signs, fractions, scientific notation, and values
outside that range fail before a pool is created. An absent or empty value
preserves the driver's default and `PGPORT` behavior. Other drivers ignore this
PostgreSQL setting.

When PostgreSQL is selected, set `RADIUS_DEMO_POSTGRESQL_TLS=verify-full` and
`RADIUS_DEMO_POSTGRESQL_CA_FILE` to a readable file containing PEM CA certificates
to verify the server certificate and its hostname. Mount only the public CA
bundle into the client, never a server or CA private key. This requires a server
that already supports TLS; these client settings do not enable TLS on the server.
The existing PostgreSQL Bicep sample is unchanged.

Explicit TLS overrides ambient `PGSSLMODE`, including `disable` and `no-verify`.
An unsupported mode, a CA file without the mode, or a missing, unreadable, empty,
or invalid CA bundle fails explicitly, without a plaintext retry.
If both settings are absent, the client preserves node-postgres defaults,
including `PGSSLMODE`. The projected `CONNECTION_POSTGRESQL_TLS` value is not an
opt-in: older Recipes can report `required` while running a plaintext server.
Other database drivers ignore these PostgreSQL-specific settings.

Run the client regression tests with `npm test` from `samples/demo`.
