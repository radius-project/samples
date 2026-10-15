#!/usr/bin/env python3
"""Focused preparation checks; no cluster, network, or third-party test framework."""

import importlib.util
import hashlib
import io
import json
import os
import pathlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

PATH = pathlib.Path(__file__).with_name("prepare-tls.py")
SPEC = importlib.util.spec_from_file_location("prepare_tls", PATH)
PREPARE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREPARE)
CA = "-----BEGIN CERTIFICATE-----\npublic-test-fixture\n-----END CERTIFICATE-----\n"
IMAGE = "sampleregistry:5000/samples/demo@sha256:" + "a" * 64


class PreparationTests(unittest.TestCase):
    def test_pinned_sources_private_parameters_and_exact_omission(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = pathlib.Path(temporary) / "private"
            with patch.object(PREPARE, "prepare_docs_probes", return_value={}), patch.object(PREPARE, "SCHEMA_SHA256", hashlib.sha256(b"extension kubernetes\n").hexdigest()), patch("sys.stdout", new_callable=io.StringIO), patch.object(
                PREPARE.urllib.request, "urlopen",
                side_effect=lambda *a, **kw: io.BytesIO(b"extension kubernetes\n"),
            ) as request:
                PREPARE.prepare(target, IMAGE, CA)
            self.assertEqual(request.call_count, 4)
            for call in request.call_args_list:
                self.assertIn(f"/{PREPARE.COMMIT}/", call.args[0])
            parameters = json.loads((target / "parameters.json").read_text())["parameters"]
            self.assertEqual(parameters["image"]["value"], IMAGE)
            self.assertEqual(parameters["postgresqlCaCertificate"]["value"], CA)
            self.assertEqual(len(parameters["password"]["value"]), 48)
            if os.name != "nt":
                self.assertEqual((target / "parameters.json").stat().st_mode & 0o777, 0o600)
            root = PATH.resolve().parents[3]
            source = (root / "samples/demo/app-postgresql.bicep").read_text()
            for source_file in (root / "samples/demo").glob("*.bicep"):
                self.assertEqual((target / "public" / source_file.name).read_bytes(), source_file.read_bytes())
            self.assertEqual(
                json.loads((target / "public/bicepconfig.json").read_text())["extensions"]["radius"],
                "../radius-extension.tgz",
            )
            self.assertNotIn("postgresqlTls", parameters)
            self.assertEqual((target / "omitted-policy.bicep").read_text(), source.replace("    tls: postgresqlTls\n", "", 1))

    def test_disabled_requires_no_ca(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = pathlib.Path(temporary) / "disabled"
            with patch.object(PREPARE, "prepare_docs_probes", return_value={}), patch.object(PREPARE, "SCHEMA_SHA256", hashlib.sha256(b"extension kubernetes\n").hexdigest()), patch("sys.stdout", new_callable=io.StringIO), patch.object(
                PREPARE.urllib.request, "urlopen", side_effect=lambda *a, **kw: io.BytesIO(b"extension kubernetes\n"),
            ):
                PREPARE.prepare(target, IMAGE, "", "disabled")
            parameters = json.loads((target / "parameters.json").read_text())["parameters"]
            self.assertEqual(parameters["postgresqlTls"], {"value": "disabled"})
            self.assertNotIn("postgresqlCaCertificate", parameters)

    def test_rejects_unknown_tutorial_policy(self):
        with tempfile.TemporaryDirectory() as temporary:
            for mode in ("", "optional", "disable", "unknown"):
                with self.subTest(mode=mode), self.assertRaises(ValueError):
                    PREPARE.prepare(pathlib.Path(temporary) / "unused", IMAGE, CA, mode)

    def test_rejects_changed_candidate_schema(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(
            PREPARE.urllib.request, "urlopen", side_effect=lambda *a, **kw: io.BytesIO(b"changed schema"),
        ), self.assertRaisesRegex(ValueError, "reviewed aggregate input"):
            PREPARE.prepare(pathlib.Path(temporary) / "unused", IMAGE, CA)

    def test_rejects_nonlocal_or_injected_image_and_private_key(self):
        with tempfile.TemporaryDirectory() as temporary:
            for image in ["", "ghcr.io/radius-project/samples/demo:latest", IMAGE + "'"]:
                with self.subTest(image=image), self.assertRaises(ValueError):
                    PREPARE.prepare(pathlib.Path(temporary) / "unused", image, CA)
            for ca in ["", "-----BEGIN PRIVATE KEY-----", CA + "PRIVATE KEY"]:
                with self.subTest(ca=ca), self.assertRaises(ValueError):
                    PREPARE.prepare(pathlib.Path(temporary) / "unused", IMAGE, ca)

    def test_refuses_existing_private_directory(self):
        with tempfile.TemporaryDirectory() as temporary, self.assertRaises(FileExistsError):
            PREPARE.prepare(pathlib.Path(temporary), IMAGE, CA)


class DocsProbeTests(unittest.TestCase):
    SOURCE = b"```bash\nca_input=/dev/null\n```\n\n```bash\nnode - <<'NODE'\nconst probe = true;\nNODE\n```\n"
    PROBES = {
        "docs-node-verification.cjs": b"const probe = true;\n",
        "docs-psql-verification.sh": b"ca_input=/dev/null\n",
    }
    HASHES = {name: hashlib.sha256(payload).hexdigest() for name, payload in PROBES.items()}

    def test_pinned_extraction_and_runtime_drift_check(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(
            PREPARE, "DOCS_SHA256", hashlib.sha256(self.SOURCE).hexdigest(),
        ), patch.object(PREPARE, "DOCS_PROBE_SHA256", self.HASHES), patch.object(
            PREPARE.urllib.request, "urlopen", return_value=io.BytesIO(self.SOURCE),
        ) as request:
            root = pathlib.Path(temporary)
            evidence = PREPARE.prepare_docs_probes(root)
            self.assertIn(f"/{PREPARE.DOCS_COMMIT}/{PREPARE.DOCS_PATH}", request.call_args.args[0])
            self.assertEqual(evidence["commit"], PREPARE.DOCS_COMMIT)
            self.assertEqual(evidence["probes"], self.HASHES)
            for name, expected in self.PROBES.items():
                self.assertEqual((root / name).read_bytes(), expected)
            result = subprocess.run(["sha256sum", "--check", "docs-probes.sha256"], cwd=root, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            (root / "docs-node-verification.cjs").write_bytes(b"changed\n")
            result = subprocess.run(["sha256sum", "--check", "docs-probes.sha256"], cwd=root, capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_rejects_source_drift(self):
        with self.assertRaisesRegex(ValueError, "signed checkpoint"):
            PREPARE.extract_docs_probes(b"changed documentation")

    def test_docs_runtime_modes_and_failures(self):
        source = PATH.with_name("verify-tls.sh").read_text()
        checks = source[source.index('(cd "$work/prepared"'):source.index("\nkubectl get pods")]
        for mode, failure, expected in [
            ("required", "", 0), ("disabled", "", 0),
            ("disabled", "psql", 61), ("required", "node", 62),
            ("disabled", "tamper", 1),
        ]:
            with self.subTest(mode=mode, failure=failure), tempfile.TemporaryDirectory(prefix="docs probes ") as temporary:
                root = pathlib.Path(temporary)
                prepared = root / "prepared"
                prepared.mkdir()
                evidence = root / "evidence"
                evidence.mkdir()
                psql = prepared / "docs-psql-verification.sh"
                psql.write_text("""
[[ "$DB_NAME" == postgresql-tutorial && "$NAMESPACE" == radius-tutorial ]]
[[ "$KUBE_CONTEXT" == owned-test && "$DB_HOST" == test-host ]]
if [[ "$POSTGRESQL_TLS" == required ]]; then
  [[ "$TLS_DIR" == "$EXPECTED_TLS_DIR" ]]
else
  [[ "$POSTGRESQL_TLS" == disabled && ! -v TLS_DIR ]]
fi
if [[ "$PROBE_FAIL" == psql ]]; then exit 61; fi
echo "docs psql $POSTGRESQL_TLS"
""")
                node = prepared / "docs-node-verification.cjs"
                node.write_bytes(b"exact-node-payload\n")
                (prepared / "docs-probes.sha256").write_text("".join(
                    f"{hashlib.sha256(file.read_bytes()).hexdigest()}  {file.name}\n" for file in (psql, node)
                ))
                if failure == "tamper":
                    node.write_bytes(b"changed-node-payload\n")
                result = subprocess.run(["bash", "-c", """
set -euo pipefail
work=$1
evidence=$2
mode=$3
host=test-host
kubectl() {
  [[ "$*" == *"--context owned-test"* && "$*" == *"node - $mode" ]]
  [[ "$(cat)" == exact-node-payload ]]
  if [[ "$PROBE_FAIL" == node ]]; then return 62; fi
  echo "docs node $mode"
}
""" + checks, "docs-runtime", str(root), str(evidence), mode], env={
                    **os.environ, "POSTGRESQL_TEST_CONTEXT": "owned-test",
                    "EXPECTED_TLS_DIR": str(root), "TLS_DIR": "must-not-leak",
                    "PROBE_FAIL": failure,
                }, capture_output=True, text=True)
                self.assertEqual(result.returncode, expected, result.stderr)
                if not failure:
                    self.assertEqual((evidence / "docs-psql.txt").read_text(), f"docs psql {mode}\n")
                    self.assertEqual((evidence / "docs-node.txt").read_text(), f"docs node {mode}\n")

    def test_rejects_missing_duplicate_and_changed_payloads(self):
        variants = [
            self.SOURCE.replace(b"ca_input=", b"other="),
            self.SOURCE + self.SOURCE,
            self.SOURCE.replace(b"true;", b"false;"),
        ]
        for source in variants:
            with self.subTest(source=source), patch.object(
                PREPARE, "DOCS_SHA256", hashlib.sha256(source).hexdigest(),
            ), patch.object(PREPARE, "DOCS_PROBE_SHA256", self.HASHES), self.assertRaises(ValueError):
                PREPARE.extract_docs_probes(source)


class LookupTests(unittest.TestCase):
    def run_fixture(self, script, status, output, check_env=False, env_style="current", env_only=False):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            evidence = root / "evidence"
            evidence.mkdir()
            fixture = PATH.with_name(script)
            if env_only:
                source = fixture.read_text().split("\nrad_env() {", 1)[1].split("\nkubectl create namespace", 1)[0]
                fixture = root / "environment-check.sh"
                fixture.write_text("rad_env() {" + source + """
for command in create switch show delete; do
  output=$(rad_env "$command" tutorial)
done
""")
            if script == "negative-tls.sh":
                source = fixture.read_text().split("\nidentity=$(server_identity)\n", 1)[0]
                fixture = root / "delete-check.sh"
                fixture.write_text(source + """
identity=$(server_identity)
delete_and_verify
echo "Deletion verified" > "$evidence/lifecycle.txt"
rad deploy next-stage
""")
            result = subprocess.run(
                ["bash", "-c", """
set -euo pipefail
kubectl() {
  case "$1 $2 ${3-}" in
    "config current-context ") echo owned-test ;;
    "get namespace radius-tutorial")
      if [[ "$*" == *jsonpath* ]]; then
        echo postgresql-tls
      else
        printf '%s' "$LOOKUP_OUTPUT"
        if [[ "$LOOKUP_STATUS" != 0 ]]; then echo "Mock lookup failed" >&2; fi
        return "$LOOKUP_STATUS"
      fi ;;
    "get secret postgresql-tutorial-tls")
      echo '{"metadata":{"uid":"owned-uid"},"data":{"tls.crt":"public-fixture"}}' ;;
    "get secret postgresql-ca-tutorial")
      printf '%s' "$LOOKUP_OUTPUT"
      if [[ "$LOOKUP_STATUS" != 0 ]]; then echo "Mock lookup failed" >&2; fi
      return "$LOOKUP_STATUS" ;;
    "create namespace radius-tutorial"|"label namespace radius-tutorial")
      [[ "$CHECK_ENV" == 1 ]] ;;
    *) echo "Unexpected kubectl command: $*" >&2; exit 99 ;;
  esac
}
rad() {
  if [[ "$1" == version ]]; then echo "Mock CLI"; return; fi
  if [[ "$CHECK_ENV" == 1 ]]; then
    case "$1 $2" in
      "group list"|"workspace list") echo '[]'; return ;;
      "group create"|"workspace create") return ;;
      "env "*)
        if [[ "${3-}" == --help ]]; then
          if [[ "$ENV_STYLE" == help-error ]]; then
            echo "Mock help failed" >&2
            return 42
          fi
          if [[ "$ENV_STYLE" == malformed-help ]]; then echo "Unexpected output"; return; fi
          printf 'Usage:\n  rad env %s [flags]\n' "$2"
          if [[ "$ENV_STYLE" == preview ]]; then echo "      --preview   Use Radius.Core"; fi
          return 0
        fi
        if [[ "$ENV_STYLE" == preview && " $* " != *" --preview "* ]]; then
          echo "Preview CLI requires --preview to select Radius.Core" >&2
          exit 99
        elif [[ "$ENV_STYLE" != preview && " $* " == *" --preview "* ]]; then
          echo "Unsupported env --preview flag" >&2
          exit 99
        fi
        if [[ "$2" == show ]]; then
          if [[ "$ENV_STYLE" == legacy-result ]]; then
            echo '{"type":"Applications.Core/environments","properties":{"compute":{"namespace":"radius-tutorial"}}}'
          else
            echo '{"type":"Radius.Core/environments","properties":{"providers":{"kubernetes":{"namespace":"radius-tutorial"}}}}'
          fi
        fi
        return ;;
    esac
  fi
  case "$1 $2" in
    "group list"|"deploy "*)
      echo "Reached next stage" >&2
      exit 73 ;;
    "app delete") echo "Deleted owned app" ;;
    *) echo "Unexpected rad command: $*" >&2; exit 99 ;;
  esac
}
openssl() { echo "Reached next stage" >&2; exit 73; }
source "$1" "$2" "$3" sampleregistry:5000/samples/demo:test localhost:51351
""", "fixture-test", str(fixture), str(root / "private"), str(evidence)],
                env={
                    **os.environ, "POSTGRESQL_TEST_CONTEXT": "owned-test",
                    "LOOKUP_STATUS": str(status), "LOOKUP_OUTPUT": output,
                    "CHECK_ENV": "1" if check_env else "0",
                    "ENV_STYLE": env_style,
                },
                capture_output=True, text=True,
            )
            lifecycle = evidence / "lifecycle.txt"
            return result, lifecycle.exists()

    def test_current_edge_environment_commands(self):
        for style in ("current", "preview"):
            with self.subTest(style=style):
                result, _ = self.run_fixture("configure-tls.sh", 0, "", check_env=True, env_style=style)
                self.assertEqual(result.returncode, 73, result.stderr)
                self.assertIn("Reached next stage", result.stderr)

    def test_all_environment_commands_select_supported_flags(self):
        for style in ("current", "preview"):
            with self.subTest(style=style):
                result, _ = self.run_fixture("configure-tls.sh", 0, "", check_env=True, env_style=style, env_only=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_environment_help_errors_do_not_fall_back(self):
        for env_only in (False, True):
            with self.subTest(command_substitution=env_only):
                result, _ = self.run_fixture(
                    "configure-tls.sh", 0, "", check_env=True, env_style="help-error", env_only=env_only,
                )
                self.assertEqual(result.returncode, 42, result.stderr)
                self.assertIn("Mock help failed", result.stderr)

    def test_malformed_help_does_not_select_legacy_commands(self):
        result, _ = self.run_fixture("configure-tls.sh", 0, "", check_env=True, env_style="malformed-help")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("invalid help output", result.stderr)

    def test_legacy_environment_is_not_accepted(self):
        result, _ = self.run_fixture("configure-tls.sh", 0, "", check_env=True, env_style="legacy-result")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Expected a Radius.Core environment", result.stderr)

    def test_namespace_lookup_requires_success_and_absence(self):
        for status, output, expected in [
            (42, "", 42), (0, "namespace/radius-tutorial", 1), (0, "", 73),
        ]:
            with self.subTest(status=status, output=output):
                result, _ = self.run_fixture("configure-tls.sh", status, output)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual("Reached next stage" in result.stderr, expected == 73)
                if status:
                    self.assertIn("Mock lookup failed", result.stderr)

    def test_ca_deletion_requires_successful_absence_lookup(self):
        for status, output, expected in [
            (42, "", 42), (0, "secret/postgresql-ca-tutorial", 1), (0, "", 73),
        ]:
            with self.subTest(status=status, output=output):
                result, lifecycle = self.run_fixture("negative-tls.sh", status, output)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual(lifecycle, expected == 73)
                self.assertEqual("Reached next stage" in result.stderr, expected == 73)
                if status:
                    self.assertIn("Mock lookup failed", result.stderr)


if __name__ == "__main__":
    unittest.main()
