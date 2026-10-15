#!/usr/bin/env python3
"""Prepare private pinned Recipes and parameter files, never published artifacts."""

import hashlib
import json
import pathlib
import re
import secrets
import sys
import urllib.request

COMMIT = "c587abffceeb0296bc9a6e10f2835b9a6cdf56a4"
SCHEMA_SHA256 = "97050356f94dc08e2939ecde0ed4171d1191fde6ecaa303fe7e6457a70f53f24"
RECIPES = {
    "postgresql": "Data/postgreSqlDatabases/recipes/kubernetes/bicep/kubernetes-postgresql.bicep",
    "containers": "Compute/containers/recipes/kubernetes/bicep/kubernetes-containers.bicep",
    "secrets": "Security/secrets/recipes/kubernetes/bicep/kubernetes-secrets.bicep",
}


def prepare(directory, image, ca, mode="required"):
    if mode not in ("required", "disabled"):
        raise ValueError("Tutorial policy must be required or disabled.")
    if not re.fullmatch(r"sampleregistry:5000/samples/demo(?:@sha256:[a-f0-9]{64}|:[a-zA-Z0-9_.-]+)", image):
        raise ValueError("Use the explicitly built image in the isolated samples registry.")
    if mode == "required" and (not ca.startswith("-----BEGIN CERTIFICATE-----") or "PRIVATE KEY" in ca):
        raise ValueError("Expected a public PEM CA certificate, never private key material.")
    directory.mkdir(mode=0o700, parents=True, exist_ok=False)
    evidence = []
    for name, path in RECIPES.items():
        url = f"https://raw.githubusercontent.com/radius-project/resource-types-contrib/{COMMIT}/{path}"
        with urllib.request.urlopen(url, timeout=60) as response:
            content = response.read()
        (directory / f"{name}.bicep").write_bytes(content)
        evidence.append({"commit": COMMIT, "path": path, "sha256": hashlib.sha256(content).hexdigest()})
    schema_path = "Data/postgreSqlDatabases/postgreSqlDatabases.yaml"
    with urllib.request.urlopen(
        f"https://raw.githubusercontent.com/radius-project/resource-types-contrib/{COMMIT}/{schema_path}", timeout=60,
    ) as response:
        content = response.read()
    if hashlib.sha256(content).hexdigest() != SCHEMA_SHA256:
        raise ValueError("Candidate PostgreSQL schema does not match the reviewed aggregate input.")
    (directory / "postgresql.yaml").write_bytes(content)
    evidence.append({"commit": COMMIT, "path": schema_path, "sha256": hashlib.sha256(content).hexdigest()})
    parameters = {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {
            "password": {"value": secrets.token_hex(24)},
            "image": {"value": image},
        },
    }
    if mode == "required":
        parameters["parameters"]["postgresqlCaCertificate"] = {"value": ca}
    else:
        parameters["parameters"]["postgresqlTls"] = {"value": "disabled"}
    path = directory / "parameters.json"
    with path.open("x", encoding="utf-8") as stream:
        path.chmod(0o600)
        json.dump(parameters, stream)
    root = pathlib.Path(__file__).resolve().parents[3]
    public = directory / "public"
    public.mkdir()
    for source_file in (root / "samples/demo").glob("*.bicep"):
        (public / source_file.name).write_bytes(source_file.read_bytes())
    for target, extension in [(directory, "./radius-extension.tgz"), (public, "../radius-extension.tgz")]:
        (target / "bicepconfig.json").write_text(
            json.dumps({"extensions": {"radius": extension}}), encoding="utf-8",
        )
    source = (root / "samples/demo/app-postgresql.bicep").read_text(encoding="utf-8")
    policy = "    tls: postgresqlTls\n"
    assert source.count(policy) == 1
    (directory / "omitted-policy.bicep").write_text(source.replace(policy, "", 1), encoding="utf-8")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    mode = sys.argv[4] if len(sys.argv) > 4 else "required"
    ca = pathlib.Path(sys.argv[3]).read_text() if mode == "required" else ""
    prepare(pathlib.Path(sys.argv[1]), sys.argv[2], ca, mode)
