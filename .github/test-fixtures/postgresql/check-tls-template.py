#!/usr/bin/env python3
"""Compile the public templates and assert their TLS/ownership contract."""

import json
import pathlib
import subprocess
import sys


def compile_template(binary, path):
    result = subprocess.run(
        [binary, "build", str(path), "--stdout"],
        check=True, capture_output=True, text=True,
    )
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    return json.loads(result.stdout)


def check(binary):
    root = pathlib.Path(__file__).resolve().parents[3]
    app = compile_template(binary, root / "samples/demo/app-postgresql.bicep")
    pack = compile_template(binary, root / "samples/demo/postgresql-tls-pack.bicep")
    parameters = app["parameters"]
    assert set(parameters) == {"environment", "password", "image", "postgresqlCaCertificate"}
    assert all("defaultValue" not in value for value in parameters.values())
    assert parameters["password"]["type"] == "securestring"
    assert parameters["image"]["minLength"] == 1
    assert parameters["postgresqlCaCertificate"]["minLength"] == 1
    resources = app["resources"]
    assert set(resources) == {
        "demoApp", "demoContainer", "postgresql", "postgresqlCredentials", "postgresqlCa",
    }
    database = resources["postgresql"]["properties"]["properties"]
    assert database["tls"] == "required"
    assert database["password"] == "[parameters('password')]"
    assert database["database"] == "appdb"
    assert database["username"] == "myadmin"
    container = resources["demoContainer"]
    props = container["properties"]["properties"]
    web = props["containers"]["web"]
    assert web["image"] == "[parameters('image')]"
    assert web["env"] == {
        "RADIUS_DEMO_POSTGRESQL_TLS": {"value": "verify-full"},
        "RADIUS_DEMO_POSTGRESQL_CA_FILE": {"value": "/etc/postgresql-ca/ca.crt"},
    }
    assert web["volumeMounts"] == [
        {"volumeName": "postgresql-ca", "mountPath": "/etc/postgresql-ca"},
    ]
    assert props["volumes"] == {
        "postgresql-ca": {"secretName": "[reference('postgresqlCa').name]"},
    }
    assert props["connections"] == {
        "postgresql": {"source": "[reference('postgresql').id]"},
        "postgresqlCredentials": {"source": "[reference('postgresqlCredentials').id]"},
    }
    assert set(container["dependsOn"]) == {
        "demoApp", "postgresql", "postgresqlCa", "postgresqlCredentials",
    }
    ca = resources["postgresqlCa"]["properties"]
    assert ca["properties"]["application"] == "[reference('demoApp').id]"
    assert ca["properties"]["data"] == {
        "ca.crt": {"value": "[parameters('postgresqlCaCertificate')]"},
    }
    assert resources["postgresqlCredentials"]["properties"]["properties"]["data"] == {
        "password": {"value": "[parameters('password')]"},
    }
    expected_names = {
        "demoApp": "demo", "demoContainer": "demo", "postgresql": "postgresql",
        "postgresqlCredentials": "postgresql-credentials", "postgresqlCa": "postgresql-ca",
    }
    for symbol, prefix in expected_names.items():
        assert resources[symbol]["properties"]["name"] == (
            f"[format('{prefix}-{{0}}', variables('environmentName'))]"
        )
    # The new CA Secret must never alias any existing credential or server Secret.
    for environment in ["tutorial", "dev", "credentials", "tls", "ca"]:
        names = {
            f"postgresql-{environment}-tls", f"postgresql-{environment}-credentials",
            f"postgresql-credentials-{environment}",
        }
        assert f"postgresql-ca-{environment}" not in names
    assert set(pack["parameters"]) == {
        "packName", "postgresqlRecipeSource", "containerRecipeSource", "secretRecipeSource",
    }
    assert all("defaultValue" not in value for value in pack["parameters"].values())
    assert pack["variables"]["sources"] == {
        "Radius.Data/postgreSqlDatabases": "[parameters('postgresqlRecipeSource')]",
        "Radius.Compute/containers": "[parameters('containerRecipeSource')]",
        "Radius.Security/secrets": "[parameters('secretRecipeSource')]",
    }
    assert pack["resources"]["pack"]["type"] == "Radius.Core/recipePacks@2025-08-01-preview"
    print("Public TLS templates compiled; identity, required inputs, CA-only mount, dependency, and pack mappings passed.")


if __name__ == "__main__":
    check(sys.argv[1])
