import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const phase = process.argv[2];
assert(["before", "after"].includes(phase), "Expected before or after");
const source = process.env.POSTGRESQL_DISABLED_RECIPE_SOURCE;
const digest = process.env.POSTGRESQL_DISABLED_RECIPE_DIGEST;
assert(source, "Publication gate: set POSTGRESQL_DISABLED_RECIPE_SOURCE to a reviewed public policy-aware recipe");
assert(/^sha256:[a-f0-9]{64}$/.test(digest ?? ""), "Publication gate: set POSTGRESQL_DISABLED_RECIPE_DIGEST to its reviewed OCI digest");

function run(command, args, input) {
  const result = spawnSync(command, args, {
    encoding: "utf8",
    input,
    timeout: 240_000,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (result.error) throw result.error;
  assert.equal(result.status, 0, `${command} ${args.join(" ")} failed: ${result.stderr}`);
  return result.stdout.trim();
}

const json = (command, args) => JSON.parse(run(command, args));
const environment = json("rad", ["resource", "show", "Radius.Core/environments", "default", "-o", "json"]);
assert.notEqual(environment.properties.simulated, true, "A simulated deployment is not acceptance");
assert(!environment.properties.providers?.azure && !environment.properties.providers?.aws, "Kubernetes-only demo");
const packs = environment.properties.recipePacks;
assert(packs?.length, "Environment must have actual assigned recipe packs");
const types = ["Radius.Data/postgreSqlDatabases", "Radius.Compute/containers", "Radius.Security/secrets"];
const selected = {};
for (const id of packs) {
  const match = id.match(/^\/planes\/radius\/local\/resourceGroups\/([^/]+)\/providers\/Radius.Core\/recipePacks\/([^/]+)$/i);
  assert(match, "Unexpected recipe pack ID");
  const pack = json("rad", ["recipe-pack", "show", match[2], "--group", match[1], "-o", "json"]);
  assert.equal(pack.id.toLowerCase(), id.toLowerCase());
  for (const type of types) {
    const entry = Object.entries(pack.properties.recipes).find(([key]) => key.toLowerCase() === type.toLowerCase());
    if (!entry || selected[type]) continue;
    const recipe = entry[1];
    // Match Radius's first-pack selection; environment parameters override pack defaults.
    const parameters = { ...recipe.parameters, ...environment.properties.recipeParameters?.[type] };
    assert.equal(Object.keys(parameters).length, 0, `This bounded demo does not approve recipe parameter overrides for ${type}`);
    assert.equal(recipe.kind, "bicep");
    assert.notEqual(recipe.plainHttp, true);
    assert(!recipe.outputs, "Unexpected output mapping override");
    const resolved = run("oras", ["resolve", recipe.source]);
    selected[type] = { pack: id, source: recipe.source, digest: resolved, parameters };
  }
}
for (const type of types) assert(selected[type], `No effective recipe for ${type}`);
assert.equal(selected[types[0]].source, source, "Effective PostgreSQL source differs from approved source");
assert.equal(selected[types[0]].digest, digest, "Effective PostgreSQL artifact differs from approved digest");

const evidencePath = join(process.env.RUNNER_TEMP, "postgresql-disabled-evidence.json");
const extension = JSON.parse(readFileSync("bicepconfig.json", "utf8")).extensions.radius;
assert(extension.startsWith("br:"), "Expected a public OCI Radius extension");
const evidence = {
  sourceCommit: process.env.GITHUB_SHA,
  radius: run("rad", ["version"]),
  cliChecksum: run("sha256sum", [run("which", ["rad"])]),
  extension: { source: extension, digest: run("oras", ["resolve", extension.slice(3)]) },
  environment: environment.id,
  recipes: selected,
  imageScope: "locally built source image; NOT published-image tutorial acceptance",
};
if (phase === "after") {
  const before = JSON.parse(readFileSync(evidencePath, "utf8"));
  assert.deepEqual(selected, before.recipes, "Recipe identity changed during deployment");
  assert.deepEqual(evidence.extension, before.extension, "Extension identity changed during deployment");
  const database = json("rad", ["resource", "show", types[0], "postgresql-default", "-o", "json"]);
  assert.equal(database.properties.tls, "disabled");
  assert.equal(database.properties.environment.toLowerCase(), environment.id.toLowerCase());
  const deployments = json("kubectl", ["get", "deployments", "-A", "-l", "radapp.io/application=demo-default", "-o", "json"]).items;
  assert.equal(deployments.length, 2, "Expected only database and demo deployments");
  const namespaces = new Set(deployments.map((deployment) => deployment.metadata.namespace));
  assert.equal(namespaces.size, 1);
  const [namespace] = namespaces;
  if (environment.properties.providers?.kubernetes?.namespace) {
    assert.equal(namespace, environment.properties.providers.kubernetes.namespace);
  }
  for (const deployment of deployments) {
    run("kubectl", ["rollout", "status", `deployment/${deployment.metadata.name}`, "-n", namespace, "--timeout=180s"]);
    const current = json("kubectl", ["get", "deployment", deployment.metadata.name, "-n", namespace, "-o", "json"]);
    assert(current.status.observedGeneration >= current.metadata.generation);
    assert.equal(current.status.updatedReplicas, 1);
    assert.equal(current.status.readyReplicas, 1);
    const spec = current.spec.template.spec;
    assert.equal((spec.volumes ?? []).filter((volume) => volume.secret || volume.projected).length, 0, "Unexpected Secret/CA volume");
    assert.equal((spec.initContainers ?? []).length, 0, "Unexpected certificate setup container");
  }
  const secrets = json("kubectl", ["get", "secrets", "-n", namespace, "-o", "json"]).items;
  for (const secret of secrets) {
    assert.notEqual(secret.type, "kubernetes.io/tls", "Unexpected TLS Secret");
    assert(!Object.keys(secret.data ?? {}).some((key) => /\.(crt|key|pem)$/i.test(key)), "Unexpected certificate/key Secret");
  }
  const maps = json("kubectl", ["get", "configmaps", "-n", namespace, "-o", "json"]).items;
  for (const map of maps) {
    if (map.metadata.name === "kube-root-ca.crt") continue;
    assert(!Object.keys(map.data ?? {}).some((key) => /\.(crt|key|pem)$/i.test(key)), "Unexpected client CA ConfigMap");
  }
  const pods = json("kubectl", ["get", "pods", "-n", namespace, "-l", "radapp.io/application=demo-default", "-o", "json"]).items
    .filter((pod) => !pod.metadata.deletionTimestamp);
  assert.equal(pods.length, 2, "Expected only the current database and demo pods");
  for (const pod of pods) {
    assert(pod.status.conditions.some((condition) => condition.type === "Ready" && condition.status === "True"));
  }
  const demo = pods.find((pod) => pod.metadata.labels["radapp.io/resource"] === "demo-default");
  const db = pods.find((pod) => pod.metadata.labels["radapp.io/resource"] === "postgresql-default");
  assert(demo && db, "Missing current application pods");
  const web = demo.spec.containers.find((container) => container.name === "web");
  assert(web, "Missing demo web container");
  assert.equal(web.image, "sampleregistry:5000/samples/demo", "CI must use the locally built image override");
  assert.equal(web.env.find((variable) => variable.name === "PGSSLMODE")?.value, "disable");
  assert(web.env.find((variable) => variable.name === "CONNECTION_POSTGRESQLCREDENTIALS_PASSWORD")?.valueFrom?.secretKeyRef,
    "Password must use the authored Secret projection, not literal env");
  assert.equal(db.spec.containers.find((container) => container.name === "postgres").env
    .find((variable) => variable.name === "POSTGRES_TLS")?.value, "disabled", "Old plaintext recipe is not policy-aware");
  const probe = readFileSync(new URL("./probe-postgresql-disabled.cjs", import.meta.url), "utf8");
  console.log(run("kubectl", ["exec", "-i", "-n", namespace, demo.metadata.name, "-c", "web", "--", "node"], probe));
  evidence.namespace = namespace;
  evidence.images = pods.map((pod) => ({
    pod: pod.metadata.name,
    containers: pod.status.containerStatuses.map(({ name, image, imageID }) => ({ name, image, imageID })),
  }));
  evidence.runtimeImages = json("kubectl", ["get", "pods", "-n", "radius-system", "-o", "json"]).items.map((pod) => ({
    pod: pod.metadata.name,
    containers: (pod.status.containerStatuses ?? []).map(({ name, image, imageID }) => ({ name, image, imageID })),
  }));
  evidence.runtimeAssertions = "passed";
}
writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
console.log(JSON.stringify(evidence, null, 2));
