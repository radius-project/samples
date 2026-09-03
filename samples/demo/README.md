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
