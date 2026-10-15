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
        raise RuntimeError("Template compilation must not emit warnings or errors.")
    return json.loads(result.stdout)


def check(binary, template_directory=None):
    root = pathlib.Path(__file__).resolve().parents[3]
    public = root / "samples/demo"
    templates = pathlib.Path(template_directory) if template_directory else public
    if templates != public:
        expected = {path.name: path.read_bytes() for path in public.glob("*.bicep")}
        assert {path.name: path.read_bytes() for path in templates.glob("*.bicep")} == expected
    app = compile_template(binary, templates / "app-postgresql.bicep")
    pack = compile_template(binary, templates / "postgresql-tls-pack.bicep")
    parameters = app["parameters"]
    assert set(parameters) == {"environment", "password", "image", "postgresqlCaCertificate", "postgresqlTls"}
    assert all("defaultValue" not in parameters[name] for name in ("environment", "password", "image"))
    assert parameters["postgresqlTls"]["defaultValue"] == "required"
    assert parameters["postgresqlTls"]["allowedValues"] == ["required", "disabled"]
    assert parameters["postgresqlCaCertificate"]["defaultValue"] == ""
    assert parameters["password"]["type"] == "securestring"
    assert parameters["image"]["minLength"] == 1
    resources = app["resources"]
    assert set(resources) == {
        "demoApp", "demoContainer", "postgresql", "postgresqlCredentials", "postgresqlCa",
    }
    database = resources["postgresql"]["properties"]["properties"]
    assert database["tls"] == "[parameters('postgresqlTls')]"
    assert database["password"] == "[parameters('password')]"
    assert database["database"] == "appdb"
    assert database["username"] == "myadmin"
    container = resources["demoContainer"]
    props = container["properties"]["properties"]
    assert "'image', parameters('image')" in props
    assert "if(variables('tlsEnabled'), createObject('RADIUS_DEMO_POSTGRESQL_TLS', createObject('value', 'verify-full'), 'RADIUS_DEMO_POSTGRESQL_CA_FILE', createObject('value', '/etc/postgresql-ca/ca.crt')), createObject('PGSSLMODE', createObject('value', 'disable')))" in props
    assert "if(variables('tlsEnabled'), createObject('volumeMounts', createArray(createObject('volumeName', 'postgresql-ca', 'mountPath', '/etc/postgresql-ca'))), createObject())" in props
    assert "if(variables('tlsEnabled'), createObject('volumes', createObject('postgresql-ca', createObject('secretName', variables('postgresqlCaName')))), createObject())" in props
    assert "reference('postgresqlCa')" not in json.dumps(app)
    assert "'connections', createObject('postgresql', createObject('source', reference('postgresql').id), 'postgresqlCredentials', createObject('source', reference('postgresqlCredentials').id))" in props
    assert set(container["dependsOn"]) == {
        "demoApp", "postgresql", "postgresqlCa", "postgresqlCredentials",
    }
    ca = resources["postgresqlCa"]["properties"]
    assert resources["postgresqlCa"]["condition"] == "[variables('tlsEnabled')]"
    assert ca["name"] == "[variables('postgresqlCaName')]"
    assert app["variables"]["postgresqlCaName"] == "[format('postgresql-ca-{0}', variables('environmentName'))]"
    assert app["variables"]["tlsEnabled"] == "[equals(parameters('postgresqlTls'), 'required')]"
    assert resources["demoApp"]["properties"]["name"] == "[variables('validatedAppName')]"
    assert app["variables"]["validatedAppName"] == (
        "[if(and(variables('tlsEnabled'), empty(trim(parameters('postgresqlCaCertificate')))), "
        "fail('postgresqlCaCertificate is required when postgresqlTls is required.'), "
        "format('demo-{0}', variables('environmentName')))]"
    )
    for symbol in ("postgresql", "postgresqlCredentials", "postgresqlCa"):
        assert resources[symbol]["dependsOn"] == ["demoApp"]
    assert ca["properties"]["application"] == "[reference('demoApp').id]"
    assert ca["properties"]["data"] == {
        "ca.crt": {"value": "[parameters('postgresqlCaCertificate')]"},
    }
    assert resources["postgresqlCredentials"]["properties"]["properties"]["data"] == {
        "password": {"value": "[parameters('password')]"},
    }
    expected_names = {
        "demoContainer": "demo", "postgresql": "postgresql",
        "postgresqlCredentials": "postgresql-credentials",
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
    print("Public templates compiled; secure default, mode guard, conditional CA wiring, identity, and pack mappings passed. Runtime evaluation is checked by CI.")


if __name__ == "__main__":
    check(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
