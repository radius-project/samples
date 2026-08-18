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

## Deploy the Redis demo

`app-redis.bicep` deploys the demo application with a Redis cache and uses the
published demo image by default:

```sh
rad deploy samples/demo/app-redis.bicep
```

The Redis resource creates a `Radius.Security/secrets` resource containing its
secret outputs. The template declares that generated resource as `existing`,
using `redis.properties.secrets.name`, and connects the container to the secret
rather than directly to the Redis resource. This declaration discovers the
generated resource; it does not create or manage a second secret.

Radius names environment variables from the connection name and each secret
key as `CONNECTION_<CONNECTION-NAME>_<SECRET-KEY>`, normalized to uppercase.
For the `redis` connection and its `url` key, the demo receives
`CONNECTION_REDIS_URL` without an explicit `secretKeyRef`. The demo uses that
URL for its Todo storage.
