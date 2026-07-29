from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts" / "run_nonempty_swift_filter.py"


FAKE_SWIFT = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

scenario = json.loads(Path(os.environ["FAKE_SWIFT_SCENARIO"]).read_text())
log_path = os.environ.get("FAKE_SWIFT_LOG")
if log_path:
    with Path(log_path).open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(sys.argv[1:]) + "\\n")
mode = "list" if "list" in sys.argv[1:] else "run"
sys.stdout.write(scenario.get(mode + "Stdout", ""))
sys.stderr.write(scenario.get(mode + "Stderr", ""))
raise SystemExit(scenario.get(mode + "Returncode", 0))
"""


class NonemptySwiftFilterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_directory.cleanup)
        self.directory = Path(self.temp_directory.name)
        self.package = self.directory / "FixturePackage"
        self.package.mkdir()
        (self.package / "Package.swift").write_text(
            "// swift-tools-version: 6.0\n",
            encoding="utf-8",
        )
        self.bin_directory = self.directory / "bin"
        self.bin_directory.mkdir()
        self.fake_swift = self.bin_directory / "swift"
        self.fake_swift.write_text(FAKE_SWIFT, encoding="utf-8")
        self.fake_swift.chmod(0o755)
        self.scenario_path = self.directory / "scenario.json"
        self.log_path = self.directory / "swift-arguments.jsonl"

    @staticmethod
    def list_output(*suites: str) -> str:
        return "".join(
            f"FixturePackageTests.{suite}/testExample\n" for suite in suites
        )

    @staticmethod
    def run_output(*suites: str) -> str:
        return "".join(
            (
                f"Test Case '-[FixturePackageTests.{suite} testExample]' "
                "passed (0.001 seconds).\n"
            )
            for suite in suites
        ) + f"Executed {len(suites)} tests, with 0 failures\n"

    def run_runner(
        self,
        scenario: dict,
        *,
        filter_value: str = "SuiteA|SuiteB",
        required_suites: tuple[str, ...] = (),
    ) -> subprocess.CompletedProcess[str]:
        self.scenario_path.write_text(
            json.dumps(scenario),
            encoding="utf-8",
        )
        environment = dict(os.environ)
        environment["PATH"] = (
            f"{self.bin_directory}{os.pathsep}{environment.get('PATH', '')}"
        )
        environment["FAKE_SWIFT_SCENARIO"] = str(self.scenario_path)
        environment["FAKE_SWIFT_LOG"] = str(self.log_path)
        command = [
            sys.executable,
            str(RUNNER),
            "--package-path",
            str(self.package),
            "--filter",
            filter_value,
        ]
        for suite in required_suites:
            command.extend(["--require-suite", suite])
        return subprocess.run(
            command,
            cwd=ROOT,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def valid_scenario(self) -> dict:
        return {
            "listStdout": self.list_output("SuiteA", "SuiteB"),
            "runStdout": self.run_output("SuiteA", "SuiteB"),
        }

    def test_closed_alternation_discovers_and_executes_every_derived_suite(self) -> None:
        result = self.run_runner(self.valid_scenario())

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SuiteA=1", result.stdout)
        self.assertIn("SuiteB=1", result.stdout)
        self.assertIn("executed=2", result.stdout)

    def test_require_suite_set_must_equal_filter_derived_set(self) -> None:
        result = self.run_runner(
            self.valid_scenario(),
            required_suites=("SuiteA",),
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--require-suite set", result.stderr)
        self.assertIn("derived set", result.stderr)

    def test_closed_filter_rejects_regex_operators_and_empty_or_duplicate_terms(self) -> None:
        for filter_value in (
            "SuiteA.*|SuiteB",
            "SuiteA||SuiteB",
            "SuiteA|SuiteA",
            "(SuiteA|SuiteB)",
            "SuiteA/",
        ):
            with self.subTest(filter_value=filter_value):
                result = self.run_runner(
                    self.valid_scenario(),
                    filter_value=filter_value,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("closed alternation", result.stderr)

    def test_list_build_failure_has_distinct_exit_and_diagnostic(self) -> None:
        result = self.run_runner(
            {
                "listReturncode": 1,
                "listStderr": "error: emit-module command failed\n",
            }
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("build failure", result.stderr)

    def test_list_tool_or_discovery_failure_is_not_no_match(self) -> None:
        result = self.run_runner(
            {
                "listReturncode": 1,
                "listStderr": "swift test list: package graph unavailable\n",
            }
        )

        self.assertEqual(result.returncode, 3)
        self.assertIn("discovery failure", result.stderr)
        self.assertNotIn("zero execution", result.stderr)

    def test_missing_derived_suite_in_list_is_discovery_failure(self) -> None:
        result = self.run_runner(
            {
                "listStdout": self.list_output("SuiteA"),
            }
        )

        self.assertEqual(result.returncode, 3)
        self.assertIn("SuiteB", result.stderr)
        self.assertIn("not discovered", result.stderr)

    def test_successful_command_with_zero_execution_is_rejected(self) -> None:
        result = self.run_runner(
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runStdout": "Executed 0 tests, with 0 failures\n",
            }
        )

        self.assertEqual(result.returncode, 4)
        self.assertIn("zero execution", result.stderr)
        self.assertIn("SuiteA", result.stderr)
        self.assertIn("SuiteB", result.stderr)

    def test_partial_suite_execution_is_rejected_even_when_total_is_nonzero(self) -> None:
        result = self.run_runner(
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runStdout": self.run_output("SuiteA"),
            }
        )

        self.assertEqual(result.returncode, 4)
        self.assertIn("SuiteB", result.stderr)
        self.assertIn("executed no tests", result.stderr)

    def test_test_failure_is_distinct_after_execution_is_proven(self) -> None:
        result = self.run_runner(
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runReturncode": 1,
                "runStdout": (
                    self.run_output("SuiteA", "SuiteB")
                    .replace("passed", "failed", 1)
                    .replace("0 failures", "1 failure")
                ),
            }
        )

        self.assertEqual(result.returncode, 5)
        self.assertIn("test failure", result.stderr)

    def test_execute_build_failure_is_distinct_from_test_failure(self) -> None:
        result = self.run_runner(
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runReturncode": 1,
                "runStderr": "error: compile command failed\n",
            }
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("build failure", result.stderr)

    def test_runner_uses_exact_package_for_list_and_execution(self) -> None:
        result = self.run_runner(self.valid_scenario())

        self.assertEqual(result.returncode, 0, result.stderr)
        invocations = [
            json.loads(line)
            for line in self.log_path.read_text(encoding="utf-8").splitlines()
        ]
        self.assertEqual(
            invocations,
            [
                ["test", "--package-path", str(self.package), "list"],
                [
                    "test",
                    "--package-path",
                    str(self.package),
                    "--filter",
                    "SuiteA|SuiteB",
                ],
            ],
        )


if __name__ == "__main__":
    unittest.main()
