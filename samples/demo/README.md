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

The `redis` connection provides both the Redis resource's non-secret values and
its secret outputs. Radius injects `CONNECTION_REDIS_HOST` and
`CONNECTION_REDIS_PORT` as normal environment variables, and injects the
generated Secret's `url` key as `CONNECTION_REDIS_URL` through a Kubernetes
`secretKeyRef`.

The demo uses `CONNECTION_REDIS_URL` for its Todo storage.
