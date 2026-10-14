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

`app-postgresql.bicep` is a **TLS-only Kubernetes example**. It sets the server
policy to `required` and the client to `verify-full`: both the certificate chain
and DNS hostname must verify. It keeps the existing application, database,
connection profile, and authored password Secret names.

**Publication is blocked.** A compatible public TLS Recipe prerelease and a
verified, retained demo image digest have not yet been selected. The `image`
parameter and all three Recipe-source parameters are therefore required, with
no defaults. Neither `demo:latest` nor the current default PostgreSQL Recipe
is a substitute. Local candidate artifacts are suitable for isolated testing,
not evidence that this tutorial is ready for public deployment.

The Kubernetes Container Recipe's direct Secret connection support projects the
database password as `CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD`. That password
projection requires Radius 0.61.0 or later; the TLS example additionally requires
the verified runtime, schema, and Recipe tuple described below.

The demo image prefers that variable and retains `CONNECTION_POSTGRESQL_PASSWORD` as a compatibility fallback for older or mixed installations whose PostgreSQL Recipe still supplies the password. If both variables are set to different values, the demo logs a warning and uses `CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD`. Azure ACI does not project direct Secret connections, so this new password path is Kubernetes-only; its existing connection behavior is unchanged.

### Deployment contract

Use a fresh, isolated Environment, not a shared default Environment. The tutorial
uses Environment `tutorial`, application `demo-tutorial`, database
`postgresql-tutorial`, and Recipe Pack `tutorial-postgresql-tls`.

1. Verify the actual CLI/runtime, the registered `Radius.Data` schema's `tls`
   property, and the Bicep extension used to compile this file. The mutable
   extension reference in `bicepconfig.json` and an unchanged API version are
   not proof of compatibility.
2. Create the isolated Environment if the CLI needs it before pack deployment.
   Deploy `postgresql-tls-pack.bicep` with `packName`,
   `postgresqlRecipeSource`, `containerRecipeSource`, and `secretRecipeSource`,
   then assign that named pack only to the isolated Environment before deploying
   the base app or database. Inspect the stored pack sources and their resolved
   digests. Sources must be raw `registry/path:tag` references, not `br:` URLs or
   digest-only Recipe references. The helper's only HTTP exception is the
   controlled `sampleregistry:5000/` used by local CI.
3. Discover and verify the Environment's Kubernetes namespace. For the tutorial
   it must be `radius-tutorial`, making the exact server hostname
   `postgresql-tutorial.radius-tutorial.svc.cluster.local`. Issue a certificate
   with that DNS SAN and verify its chain and hostname **before deployment**.
   Do not assume a namespace from the Environment's name. Create a namespace
   only after checking that it is owned by this disposable tutorial.
4. Before database deployment, use `kubectl create secret tls` with
   `--cert` and `--key` file paths to create the operator-owned
   `postgresql-tutorial-tls` Secret in that namespace. Refuse collisions rather
   than overwriting an existing Secret. Keep server and issuer private keys out
   of the repository, parameter files, client environment, and logs.
5. Supply `password`, `postgresqlCaCertificate` (the public PEM CA bundle), and
   `image` through a protected JSON parameter file. The CLI injects `environment`.
   Use a verified retained `image@sha256:...` for publication; local CI overrides
   it with its explicitly built candidate image. Container image digest
   references are supported even though Recipe digest-only references are not.
6. Wait for the database and demo Deployments to become ready. Verify the
   returned database hostname equals the certificate SAN, exercise PostgreSQL
   create/read/update/delete, and check persisted rows and `pg_stat_ssl` for the
   **Node client's session**. A successful deployment or in-memory UI is not
   evidence of an authenticated TLS connection.

The application owns a separate generic Secret, `postgresql-ca-tutorial`,
containing only `ca.crt`. The container mounts it at `/etc/postgresql-ca` through
the selected Container Recipe's Secret-volume support, with an explicit
deployment dependency. Kubernetes Secret volumes are read-only; the Radius
volume-mount schema does not expose a `readOnly` field. This CA Secret is distinct
from the operator's `postgresql-tutorial-tls`, the Recipe's
`postgresql-tutorial-credentials`, and the authored
`postgresql-credentials-tutorial`. No connection or client mount grants access
to the server Secret.

Missing or invalid server Secrets, a wrong namespace, an untrusted CA, or a
hostname mismatch must fail without falling back to plaintext. Check namespace,
Secret name, certificate validity/SAN, and the selected Recipe; do not disable
verification to recover.

Delete the application-owned resources with application deletion. The operator
server Secret must retain its original UID and data; remove it separately only
if it belongs to this tutorial and is no longer needed. Do not delete a shared
namespace. These demo Recipes use ephemeral PostgreSQL storage: Pod replacement
can erase database data. This is not a production migration or certificate
rotation procedure. Keep this demo local-only: its UI displays environment
variables, including credentials.

### Explicit client TLS

When PostgreSQL is selected, set `RADIUS_DEMO_POSTGRESQL_TLS=verify-full` and
`RADIUS_DEMO_POSTGRESQL_CA_FILE` to a readable file containing PEM CA certificates
to verify the server certificate and its hostname. Mount only the public CA
bundle into the client, never a server or CA private key. This requires a server
that already supports TLS; these client settings do not enable TLS on the server.
The PostgreSQL Bicep sample supplies these settings and the CA mount explicitly.

Explicit TLS overrides ambient `PGSSLMODE`, including `disable` and `no-verify`.
An unsupported mode, a CA file without the mode, or a missing, unreadable, empty,
or invalid CA bundle fails explicitly, without a plaintext retry.
If both settings are absent, the client preserves node-postgres defaults,
including `PGSSLMODE`. The projected `CONNECTION_POSTGRESQL_TLS` value is not an
opt-in: older Recipes can report `required` while running a plaintext server.
Other database drivers ignore these PostgreSQL-specific settings.

Run the client regression tests with `npm test` from `samples/demo`.
