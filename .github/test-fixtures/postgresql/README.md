# PostgreSQL client compatibility gate

These are private CI fixtures, not downloadable demo samples. The K3D test
workflow runs them against Radius **0.61.1 with its unmodified default Recipe
Pack**, and **edge with an explicitly selected pre-TLS Recipe Pack**.
Each matrix job has its own disposable cluster and local image registry.
Client unit tests run before cluster creation.

`prepare.py` downloads `samples/demo/app-postgresql.bicep` from samples commit
`a366d18f573797763113ac04c8f14a1230f3643e`, checks Git blob identity
`868e2846c8e4854551edce137aac756bb63c4696`, and replaces exactly one image literal
with the candidate local-registry image. It also generates a private ARM JSON
password parameter file. Generated files stay in the runner's temporary
directory; neither parameters nor Kubernetes Secrets are uploaded as evidence.
Importing an image into a cluster is insufficient for the released template's
`latest` pull behavior.

`configure.sh` requires an already installed Radius control plane and creates
an isolated namespace, resource group, workspace and environment. The edge
fixture checks the pre-TLS PostgreSQL Recipe tag's digest before selecting the
pack. Recipe sources use supported tags, not digest-only references. It records
the actual runtime, registered schemas, selected pack and resolved Recipe
digests. After deployment, CI records the Bicep compiler and cached type-extension
manifest/hash actually used by the template.

`probe.cjs` executes inside the candidate demo container using its compiled
database client. It requires the old projected `CONNECTION_POSTGRESQL_TLS=required`
hint and absent explicit TLS/ambient `PGSSLMODE` settings, asserts the PostgreSQL
factory, exercises CRUD, and verifies persisted rows through an independent SQL
connection. It checks `pg_stat_ssl` on the actual repository connection and
confirms the running HTTP endpoint is not using the in-memory backend.

For manual runs, use an owned disposable cluster, registry, namespace, `HOME`,
and `KUBECONFIG`; do not select a user's existing workspace or namespace.
If the Radius CLI requires `$HOME/.kube/config`, copy only the owned kubeconfig
there. The local-registry HTTP exception must apply only to that registry.
After collecting nonsecret evidence, delete only the owned test resources and
temporary password parameter files. Passing these checks is a pre-merge gate,
not authorization to publish images, change Recipe defaults, or merge a PR.

## Tutorial transport-mode gate

The `postgresql-tls` matrix row reuses the same K3D/local registry setup. It
compiles and deploys the public PostgreSQL app and its intentionally public
Recipe Pack helper without changing their application or connection names.
Node 20 runs the source tests; the built Node 22 image runs the same explicit
test file outside production `dist`. Existing Playwright demo CRUD runs against
the TLS deployment before the destructive negative cases.

`configure-tls.sh PRIVATE_DIRECTORY EVIDENCE_DIRECTORY IMAGE LOCAL_REGISTRY`
requires `POSTGRESQL_TEST_CONTEXT` to equal the current disposable context.
It refuses namespace/group/workspace collisions, creates `tutorial` with the
verified `radius-tutorial` namespace, issues a short-lived CA and server
certificate with the exact DNS SAN, and creates the operator TLS Secret before
database deployment. Both compilation and deployment must use the same isolated
`HOME`, kubeconfig, CLI, and `$HOME/.rad/bin/bicep`. Do not compile in a fresh
cache and then deploy using a different, stale user cache.
The fixture explicitly runs `rad bicep download` before compiler assertions:
installing the CLI/control plane does not populate a fresh HOME's Bicep binary.
Namespace collision and CA-deletion checks require successful Kubernetes lookups;
API errors must not be interpreted as absent resources. The Bash-backed fixture
unit tests cover lookup errors, existing resources, and confirmed absence.
Before deploying the database, the fixture rejects missing, empty, and whitespace
CA inputs in required mode against both a fresh app and the deployed base app.
It compares hashed resource inventories before and after each rejection.

`prepare-tls.py` downloads the PostgreSQL schema and three Bicep Recipes from contrib commit
`c587abffceeb0296bc9a6e10f2835b9a6cdf56a4`, recording their source paths and SHA-256
hashes. Recipes are compiled and published **only to the isolated local registry**.
It copies the public Bicep files byte-for-byte to a private directory with a
candidate extension configuration. Compilation checks source-byte identity and
rejects diagnostics; deployment uses the same directory and configuration.
No public imports or global type-cache files are changed.
`build-tls-types.sh` uses the official generator and aggregate index builder from
Radius commit `56fa47301fc5d310bcd3df032078357cf6cd3cb6`. It regenerates Data from
the candidate PostgreSQL manifest and the snapshot's other Data manifests,
preserves other namespace type files, and packages the local extension with the
same Bicep compiler used for deployment. The index builder runs in a disposable
Node 24 container using the pinned generator package and its exact `bicep-types`
dependency. The generated npm lock hash is recorded with the build evidence; source client tests
still run on Node 20 and in the Node 22 demo image. Go may download the toolchain
selected by the pinned generator's module into the isolated HOME.
This is candidate validation, not evidence that published `radius:latest`
supports disabled. Public extension availability remains a release gate.
The public helper selects all three tagged local candidates explicitly. The
fixture verifies the stored mappings, resolved digests, actual registered TLS
schema, compiler/type-cache hashes, and runtime images. No default `edge`
PostgreSQL Recipe is used. The image parameter selects the locally built
container by digest. Public TLS Recipe and retained client-image publication
remain separate, unmet gates.

After deploying the public sample with the protected generated
`prepared/parameters.json`, run:

```bash
bash .github/test-fixtures/postgresql/verify-tls.sh "$private" "$evidence"
# Run the existing Playwright demo tests while this deployment is healthy.
bash .github/test-fixtures/postgresql/negative-tls.sh "$private" "$evidence"
```

`verify-tls.sh` verifies readiness and returned hostname, streams only the public
CA to an authenticated `psql` probe, and runs `tls-probe.cjs` in the actual demo
container. That probe exercises HTTP CRUD, independently checks PostgreSQL rows,
queries `pg_stat_ssl` on the compiled client's repository connection, checks the
CA-only mount is readable and rejects writes with `EROFS`, and rejects wrong CA,
hostname/SAN mismatch, and plaintext clients. It never places passwords in argv.
Pass `disabled` as its third argument to assert absent demo TLS settings,
`PGSSLMODE=disable`, no certificate mount, authenticated plaintext psql and Node
sessions (`ssl=false`), persisted HTTP CRUD, wrong-password rejection, and
TLS-forcing client rejection. This branch reads no CA files.

`negative-tls.sh` repeats the checks with server policy omitted from a private
copy of the sample. It also exercises required -> disabled -> required and records
remaining Radius Secrets after conditional omission; the tutorial does not promise
automatic removal of a previously created CA. Fresh disabled and repeated disabled
deployments must succeed without either certificate Secret or a CA parameter.
Application deletion must remove the app-owned CA Secret and
leave the operator TLS Secret's UID/data hash unchanged. Only after that assertion
does the fixture deliberately damage its own server Secret to check missing
Secret, missing key, and invalid certificate failures. Finally it selects the
digest-verified old PostgreSQL Recipe and proves the explicit TLS client fails
without downgrading. It removes its applications and operator Secret, not the
namespace. Private key/parameter files must be removed on success or failure;
CI never uploads the private directory or raw Secret contents.
