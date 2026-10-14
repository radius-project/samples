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
