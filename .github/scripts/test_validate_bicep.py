import io
import os
import subprocess
import unittest
from unittest.mock import patch

import validate_bicep


class ValidateBicepTests(unittest.TestCase):
    def diagnostic(self, code="BCP036", property_name="tls", path=None, quote='"'):
        path = path or validate_bicep.postgresql_sample
        message = (
            'is not allowed on objects of type "postgreSqlDatabasesProperties".'
            if code == "BCP037"
            else """expected a value of type "'optional' | 'required' | null" but the provided value is of type "'disabled'"."""
        )
        return (
            f"{path}(61,10) : Warning {code}: The property "
            f"{quote}{property_name}{quote} {message}\n"
        )

    def test_supported_clean_compilation(self):
        self.assertFalse(validate_bicep.is_validation_failure(0, ""))

    def test_unsupported_tls_warnings_fail(self):
        for code in ("BCP036", "BCP037"):
            for quote in ('"', "'"):
                with self.subTest(code=code, quote=quote):
                    self.assertTrue(validate_bicep.is_validation_failure(
                        0, self.diagnostic(code=code, quote=quote)
                    ))

    def test_relative_path_and_different_line_number(self):
        diagnostic = self.diagnostic(
            path=os.path.relpath(validate_bicep.postgresql_sample)
        ).replace("(61,10)", "(123,4)")
        self.assertTrue(validate_bicep.is_validation_failure(0, diagnostic))

    def test_unrelated_warnings_remain_nonfatal(self):
        for diagnostic in (
            self.diagnostic(property_name="size"),
            self.diagnostic(code="BCP089"),
            self.diagnostic(path=validate_bicep.postgresql_sample.with_name("app.bicep")),
            self.diagnostic(path=validate_bicep.postgresql_sample.parent.parent / "other/app-postgresql.bicep"),
            self.diagnostic(property_name="tlsEnabled"),
        ):
            with self.subTest(diagnostic=diagnostic):
                self.assertFalse(validate_bicep.is_validation_failure(0, diagnostic))

    def test_diagnostics_do_not_match_across_lines(self):
        stderr = self.diagnostic(property_name="size") + self.diagnostic(
            path=validate_bicep.postgresql_sample.with_name("app.bicep")
        )
        self.assertFalse(validate_bicep.is_validation_failure(0, stderr))

    def test_ordinary_compiler_failures_remain_fatal(self):
        self.assertTrue(validate_bicep.is_validation_failure(1, ""))
        self.assertTrue(validate_bicep.is_validation_failure(
            0, 'another.bicep(1,1) : Error BCP001: Unrecognized token.\n'
        ))
        self.assertTrue(validate_bicep.is_validation_failure(
            1, self.diagnostic(code="BCP037").replace("Warning", "Error")
        ))

    def test_validation_exit_status(self):
        for stderr, expected in (
            ("", 0),
            (self.diagnostic(), 1),
            (self.diagnostic(code="BCP037"), 1),
            (self.diagnostic(property_name="size"), 0),
        ):
            with self.subTest(stderr=stderr):
                result = subprocess.CompletedProcess([], 0, stderr=stderr.encode())
                with (
                    patch.object(validate_bicep.os, "walk", return_value=[
                        (str(validate_bicep.postgresql_sample.parent), [], ["app-postgresql.bicep"])
                    ]),
                    patch.object(validate_bicep.subprocess, "run", return_value=result),
                    patch("sys.stdout", new_callable=io.StringIO) as output,
                ):
                    self.assertEqual(validate_bicep.main(), expected)
                    if expected:
                        self.assertIn("Failed:", output.getvalue())


if __name__ == "__main__":
    unittest.main()
