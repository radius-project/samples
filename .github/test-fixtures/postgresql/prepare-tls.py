#!/usr/bin/env python3
"""Prepare private pinned Recipes and parameter files, never published artifacts."""

import hashlib
import json
import pathlib
import re
import secrets
import sys
import urllib.request

COMMIT = "1a4c120fdab2b0f0c49bda692aef4b519855d79d"
RECIPES = {
    "postgresql": "Data/postgreSqlDatabases/recipes/kubernetes/bicep/kubernetes-postgresql.bicep",
    "containers": "Compute/containers/recipes/kubernetes/bicep/kubernetes-containers.bicep",
    "secrets": "Security/secrets/recipes/kubernetes/bicep/kubernetes-secrets.bicep",
}


def prepare(directory, image, ca):
    if not re.fullmatch(r"sampleregistry:5000/samples/demo(?:@sha256:[a-f0-9]{64}|:[a-zA-Z0-9_.-]+)", image):
        raise ValueError("Use the explicitly built image in the isolated samples registry.")
    if not ca.startswith("-----BEGIN CERTIFICATE-----") or "PRIVATE KEY" in ca:
        raise ValueError("Expected a public PEM CA certificate, never private key material.")
    directory.mkdir(mode=0o700, parents=True, exist_ok=False)
    evidence = []
    for name, path in RECIPES.items():
        url = f"https://raw.githubusercontent.com/radius-project/resource-types-contrib/{COMMIT}/{path}"
        with urllib.request.urlopen(url, timeout=60) as response:
            content = response.read()
        (directory / f"{name}.bicep").write_bytes(content)
        evidence.append({"commit": COMMIT, "path": path, "sha256": hashlib.sha256(content).hexdigest()})
    (directory / "bicepconfig.json").write_text(
        json.dumps({"extensions": {"radius": "br:biceptypes.azurecr.io/radius:latest"}}),
        encoding="utf-8",
    )
    parameters = {
        "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
        "contentVersion": "1.0.0.0",
        "parameters": {
            "password": {"value": secrets.token_hex(24)},
            "image": {"value": image},
            "postgresqlCaCertificate": {"value": ca},
        },
    }
    path = directory / "parameters.json"
    with path.open("x", encoding="utf-8") as stream:
        path.chmod(0o600)
        json.dump(parameters, stream)
    root = pathlib.Path(__file__).resolve().parents[3]
    source = (root / "samples/demo/app-postgresql.bicep").read_text(encoding="utf-8")
    policy = "    tls: 'required'\n"
    assert source.count(policy) == 1
    (directory / "omitted-policy.bicep").write_text(source.replace(policy, "", 1), encoding="utf-8")
    print(json.dumps(evidence, indent=2))


if __name__ == "__main__":
    prepare(pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3]).read_text())
