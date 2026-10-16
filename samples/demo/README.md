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

`app-postgresql.bicep` is a **plaintext, password-authenticated demo for a disposable, private Kubernetes environment**, not a production configuration. It explicitly sets the database's `tls` policy to `disabled` and the web container's `PGSSLMODE` to `disable`. No server TLS Secret or client CA is needed. Database traffic is not encrypted; password authentication does not provide transport confidentiality.

The resource's default policy remains `required`. Both `required` and `optional` require server certificates; `optional` is not a certificate-free substitute. The guarded Azure PostgreSQL recipe rejects `disabled`. See the [PostgreSQL operator guide](https://github.com/radius-project/resource-types-contrib/blob/main/Data/postgreSqlDatabases/README.md) for secure deployments and migration.

**Adoption gate:** use only a publicly available schema/Bicep extension that accepts `disabled` and a policy-aware Kubernetes PostgreSQL recipe, together with compatible Container and Secret recipes. The policy implementation is tracked in [radius-project/resource-types-contrib#394](https://github.com/radius-project/resource-types-contrib/pull/394). Until compatible artifacts are published and verified, this edge sample is not ready for tutorial adoption. A recent CLI, a successful compile with warnings, or an old recipe that happens to use plaintext does not satisfy this gate. Record the effective recipe source and resolved digest, including environment overrides, and the demo image digest when validating mutable edge artifacts.

The Kubernetes Container Recipe's direct Secret connection projects the database password as `CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD`. That credential projection requires Radius 0.61.0 or later; **this is not a minimum-version claim for the new TLS policy**.

The demo image prefers that variable and retains `CONNECTION_POSTGRESQL_PASSWORD` as a compatibility fallback for older or mixed installations whose PostgreSQL Recipe still supplies the password. If both variables are set to different values, the demo logs a warning and uses `CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD`. Azure ACI does not project direct Secret connections, so this new password path is Kubernetes-only; its existing connection behavior is unchanged.

### Deploy after the artifact gate passes

Use a fresh application in an isolated Kubernetes workspace/environment. Do not switch an existing database from required TLS to disabled. The current Kubernetes recipes do not configure durable database volumes: replacing a database pod can lose data.

From the repository root, the following Bash subshell generates a URI-safe password without exposing it in command arguments. The temporary ARM parameter file is owner-readable/writable only and is removed on success or failure. Keep shell tracing disabled. The existing `@secure()` password parameter and authored password Secret remain the credential contract.

```bash
(
  set -euo pipefail
  set +x
  umask 077
  parameters="$(mktemp)"
  trap 'rm -f "$parameters"' EXIT
  password="$(openssl rand -hex 32)"
  printf '{"$schema":"https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#","contentVersion":"1.0.0.0","parameters":{"password":{"value":"%s"}}}\n' \
    "$password" > "$parameters"
  unset password
  rad deploy samples/demo/app-postgresql.bicep --parameters "@$parameters"
)
```

The client constructs its PostgreSQL URI without escaping credentials, so use random hexadecimal passwords for this demo. `PGSSLMODE=disable` applies to its current URI without SSL query options; it is not a general-purpose TLS client configuration.

### Disabled-mode regression

The `demo-postgresql-disabled` row in `.github/workflows/test.yaml` builds the demo locally, uses a protected temporary password file, and reuses the Playwright UI checks. It also checks current rollouts, absence of certificate resources/mounts, password enforcement, `ssl=off`, plaintext transport using the same Node client configuration, and HTTP CRUD backed by persisted PostgreSQL rows.

Before enabling adoption, set repository variables `POSTGRESQL_DISABLED_RECIPE_SOURCE` and `POSTGRESQL_DISABLED_RECIPE_DIGEST` to the reviewed, publicly available policy-aware Bicep recipe source and its OCI `sha256:` digest. These are assertions, not recipe overrides: the test reads the actual environment/recipe pack and refuses a mismatch, a missing gate, or artifact drift. Do not point them at the old plaintext recipe just to make CI pass. The row does not skip dependency failures.

Local-image CI verifies source behavior only. Tutorial acceptance must separately exercise the published demo image and record its resolved digest with the exact public CLI/runtime, extension, and recipe artifacts. Neither check replaces the other.
