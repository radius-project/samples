#!/usr/bin/env python3
"""Focused preparation checks; no cluster, network, or third-party test framework."""

import importlib.util
import io
import json
import os
import pathlib
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
            with patch("sys.stdout", new_callable=io.StringIO), patch.object(
                PREPARE.urllib.request, "urlopen",
                side_effect=lambda *a, **kw: io.BytesIO(b"extension kubernetes\n"),
            ) as request:
                PREPARE.prepare(target, IMAGE, CA)
            self.assertEqual(request.call_count, 3)
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
            self.assertEqual((target / "omitted-policy.bicep").read_text(), source.replace("    tls: 'required'\n", "", 1))

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


if __name__ == "__main__":
    unittest.main()
