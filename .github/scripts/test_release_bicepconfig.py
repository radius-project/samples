# ------------------------------------------------------------
# Copyright 2026 The Radius Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT_DIR = Path(__file__).resolve().parent
FILTER = SCRIPT_DIR / "release-bicepconfig.awk"
FIXTURES = SCRIPT_DIR / "testdata"


class ReleaseBicepConfigTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (FIXTURES / "release-bicepconfig.input.json").read_text()
        cls.expected = (FIXTURES / "release-bicepconfig.expected.json").read_text()

    def rewrite(self, source, channel="1.2"):
        result = subprocess.run(
            ["awk", "-v", f"CHANNEL={channel}", "-f", str(FILTER)],
            input=source,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return result.stdout

    def test_pins_both_edge_extensions_and_preserves_other_properties(self):
        self.assertEqual(self.rewrite(self.source), self.expected)

    def test_compact_json(self):
        source = json.dumps(json.loads(self.source), separators=(",", ":"))
        expected = json.dumps(json.loads(self.expected), separators=(",", ":")) + "\n"
        self.assertEqual(self.rewrite(source), expected)

    def test_preserves_stable_references(self):
        for suffix in (
            ":latest",
            ":0.60",
            ":0.60.2",
            ":0.60.0-rc.1",
            "@sha256:" + "a" * 64,
        ):
            with self.subTest(suffix=suffix):
                source = json.dumps({
                    "extensions": {
                        alias: f"br:ghcr.io/radius-project/bicep-types-{alias}{suffix}"
                        for alias in ("radius", "aws")
                    }
                }) + "\n"
                self.assertEqual(self.rewrite(source), source)

    def test_preserves_near_matches(self):
        for alias in ("radius", "aws"):
            for reference in (
                f"br:ghcr.io/example/bicep-types-{alias}:edge",
                f"br:ghcr.io/radius-project/custom-bicep-types-{alias}:edge",
                f"br:ghcr.io/radius-project/bicep-types-{alias}:edge-preview",
                f"prefix br:ghcr.io/radius-project/bicep-types-{alias}:edge",
            ):
                with self.subTest(reference=reference):
                    source = json.dumps({"extensions": {alias: reference}}) + "\n"
                    self.assertEqual(self.rewrite(source), source)

    def test_rewrite_is_idempotent(self):
        self.assertEqual(self.rewrite(self.expected), self.expected)

    def test_channel_is_not_hardcoded(self):
        expected = json.loads(self.expected)
        for alias in ("radius", "aws"):
            expected["extensions"][alias] = (
                f"br:ghcr.io/radius-project/bicep-types-{alias}:10.20"
            )
        self.assertEqual(json.loads(self.rewrite(self.source, "10.20")), expected)

    def test_missing_channel_fails(self):
        result = subprocess.run(
            ["awk", "-f", str(FILTER)],
            input=self.source,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Error: CHANNEL is not set.", result.stderr)
        self.assertEqual(result.stdout, "")

    def test_missing_input_file_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            missing_file = Path(directory) / "bicepconfig.json"
            result = subprocess.run(
                ["awk", "-v", "CHANNEL=1.2", "-f", str(FILTER), str(missing_file)],
                text=True,
                capture_output=True,
                check=False,
            )
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(str(missing_file), result.stderr)
        self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
