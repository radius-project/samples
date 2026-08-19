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
secret outputs. The template reads the generated name from
`redis.properties.secrets.name` and combines it with the Radius resource group
ID to form the Secret connection source. This discovers the generated resource;
it does not create or manage a second secret.

Radius names environment variables from the connection name and each secret
key as `CONNECTION_<CONNECTION-NAME>_<SECRET-KEY>`, normalized to uppercase.
The template connects both resources so their properties remain distinct:

- `redis` connects the `Radius.Data/redisCaches` resource and provides
  non-secret values including `CONNECTION_REDIS_HOST` and
  `CONNECTION_REDIS_PORT`.
- `redisSecret` connects the generated `Radius.Security/secrets` resource. Its
  `url` key becomes `CONNECTION_REDISSECRET_URL` without an explicit
  `secretKeyRef`.

The demo uses `CONNECTION_REDISSECRET_URL` for its Todo storage, while continuing
to support `CONNECTION_REDIS_URL` and `REDIS_URL` for existing deployments.
