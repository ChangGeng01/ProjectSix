from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from xml.sax.saxutils import quoteattr


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts" / "run_nonempty_swift_filter.py"


FAKE_SWIFT = """#!PYTHON!
import json
import os
from pathlib import Path
import sys

scenario = json.loads(Path(os.environ["FAKE_SWIFT_SCENARIO"]).read_text())
arguments = sys.argv[1:]
log_path = os.environ.get("FAKE_SWIFT_LOG")
if log_path:
    with Path(log_path).open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(arguments) + "\\n")
if arguments and arguments[0] == "build":
    mode = "build"
elif "list" in arguments:
    mode = "list"
else:
    mode = "run"
if mode == "run" and "--xunit-output" in arguments:
    output = Path(arguments[arguments.index("--xunit-output") + 1])
    primary = scenario.get("runXunitPrimary")
    if primary is not None:
        output.write_text(primary, encoding="utf-8")
    swift_testing = scenario.get("runXunitSwiftTesting")
    if swift_testing is not None:
        sibling = output.with_name(
            output.stem + "-swift-testing" + output.suffix
        )
        sibling.write_text(swift_testing, encoding="utf-8")
sys.stdout.write(scenario.get(mode + "Stdout", ""))
sys.stderr.write(scenario.get(mode + "Stderr", ""))
if scenario.get("breakAfterMode") == mode:
    executable = Path(sys.argv[0])
    executable.unlink()
    executable.mkdir()
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
        self.fake_swift.write_text(
            FAKE_SWIFT.replace("#!PYTHON!", f"#!{sys.executable}"),
            encoding="utf-8",
        )
        self.fake_swift.chmod(0o755)
        self.scenario_path = self.directory / "scenario.json"
        self.log_path = self.directory / "swift-arguments.jsonl"

    @staticmethod
    def discovered_id(suite: str, test: str = "testExample") -> str:
        return f"FixturePackageTests.{suite}/{test}"

    @classmethod
    def list_output(cls, *suites: str) -> str:
        return "".join(f"{cls.discovered_id(suite)}\n" for suite in suites)

    @staticmethod
    def xunit(
        *cases: tuple[str, str, str],
    ) -> str:
        rows: list[str] = []
        skipped = 0
        failures = 0
        for classname, name, outcome in cases:
            if outcome == "skipped":
                body = "<skipped />"
                skipped += 1
            elif outcome == "failed":
                body = "<failure message=\"expected failure\" />"
                failures += 1
            else:
                body = ""
            rows.append(
                "    <testcase classname="
                f"{quoteattr(classname)} name={quoteattr(name)}>{body}</testcase>"
            )
        return (
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            "<testsuites>\n"
            f"  <testsuite name=\"TestResults\" tests=\"{len(cases)}\" "
            f"failures=\"{failures}\" skipped=\"{skipped}\">\n"
            + "\n".join(rows)
            + "\n  </testsuite>\n"
            "</testsuites>\n"
        )

    @staticmethod
    def case(
        suite: str,
        *,
        test: str = "testExample",
        outcome: str = "passed",
    ) -> tuple[str, str, str]:
        return (f"FixturePackageTests.{suite}", test, outcome)

    def run_runner(
        self,
        scenario: dict,
        *,
        filter_value: str = "SuiteA|SuiteB",
        required_suites: tuple[str, ...] = (),
        bin_directory: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        self.scenario_path.write_text(
            json.dumps(scenario),
            encoding="utf-8",
        )
        environment = dict(os.environ)
        selected_bin = bin_directory or self.bin_directory
        environment["PATH"] = str(selected_bin)
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
            "runXunitPrimary": self.xunit(self.case("SuiteA")),
            "runXunitSwiftTesting": self.xunit(
                self.case("SuiteB", test="testExample")
            ),
        }

    def test_closed_alternation_uses_both_xunit_files_and_exact_ids(self) -> None:
        result = self.run_runner(self.valid_scenario())

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SuiteA=1", result.stdout)
        self.assertIn("SuiteB=1", result.stdout)
        self.assertIn("executed=2", result.stdout)

    def test_fully_qualified_require_suite_set_maps_exactly_to_filter(self) -> None:
        result = self.run_runner(
            self.valid_scenario(),
            required_suites=(
                "FixturePackageTests.SuiteA",
                "FixturePackageTests.SuiteB",
            ),
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_require_suite_set_must_equal_filter_derived_set(self) -> None:
        for required in (
            ("FixturePackageTests.SuiteA",),
            (
                "FixturePackageTests.SuiteA",
                "OtherTests.SuiteA",
                "FixturePackageTests.SuiteB",
            ),
            (
                "FixturePackageTests.SuiteA",
                "FixturePackageTests.NotSuiteB",
            ),
        ):
            with self.subTest(required=required):
                result = self.run_runner(
                    self.valid_scenario(),
                    required_suites=required,
                )
                self.assertEqual(result.returncode, 1)
                self.assertIn("--require-suite set", result.stderr)
                self.assertIn("filter-derived set", result.stderr)

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
                self.assertEqual(result.returncode, 1)
                self.assertIn("closed alternation", result.stderr)

    def test_build_failure_has_distinct_exit_and_stops_before_discovery(self) -> None:
        result = self.run_runner(
            {
                "buildReturncode": 1,
                "buildStderr": "error: emit-module command failed\n",
            }
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("build failure", result.stderr)
        invocations = [
            json.loads(line)
            for line in self.log_path.read_text(encoding="utf-8").splitlines()
        ]
        self.assertEqual(
            invocations,
            [["build", "--package-path", str(self.package), "--build-tests"]],
        )

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

    def test_missing_or_ambiguous_derived_suite_is_discovery_failure(self) -> None:
        scenarios = (
            {
                "listStdout": self.list_output("SuiteA"),
            },
            {
                "listStdout": (
                    self.list_output("SuiteA", "SuiteB")
                    + "OtherTests.SuiteB/testOther\n"
                ),
            },
            {
                "listStdout": (
                    self.list_output("SuiteA", "NotSuiteB")
                ),
            },
        )
        for scenario in scenarios:
            with self.subTest(scenario=scenario):
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 3)
                self.assertIn("discovery failure", result.stderr)
                self.assertIn("SuiteB", result.stderr)

    def test_qualified_required_suite_disambiguates_duplicate_simple_name(self) -> None:
        scenario = self.valid_scenario()
        scenario["listStdout"] += "OtherTests.SuiteB/testOther\n"

        result = self.run_runner(
            scenario,
            required_suites=(
                "FixturePackageTests.SuiteA",
                "FixturePackageTests.SuiteB",
            ),
        )

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_stdout_pass_spoof_without_xunit_is_zero_execution(self) -> None:
        result = self.run_runner(
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runStdout": (
                    "Test Case '-[FixturePackageTests.SuiteA testExample]' "
                    "passed.\n"
                    "Test Case '-[FixturePackageTests.SuiteB testExample]' "
                    "passed.\n"
                ),
            }
        )

        self.assertEqual(result.returncode, 4)
        self.assertIn("structured xUnit", result.stderr)

    def test_partial_or_all_skipped_execution_is_rejected(self) -> None:
        scenarios = (
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runXunitPrimary": self.xunit(self.case("SuiteA")),
            },
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runXunitPrimary": self.xunit(
                    self.case("SuiteA", outcome="skipped"),
                    self.case("SuiteB", outcome="skipped"),
                ),
            },
        )
        for scenario in scenarios:
            with self.subTest(scenario=scenario):
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 4)
                self.assertIn("zero execution", result.stderr)

    def test_missing_primary_or_swift_testing_report_cannot_hide_expected_id(self) -> None:
        complete = self.valid_scenario()
        for missing_key in ("runXunitPrimary", "runXunitSwiftTesting"):
            with self.subTest(missing_key=missing_key):
                scenario = dict(complete)
                del scenario[missing_key]
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 4)
                self.assertIn("missing discovered test IDs", result.stderr)

    def test_each_malformed_xunit_report_is_rejected(self) -> None:
        for malformed_key in ("runXunitPrimary", "runXunitSwiftTesting"):
            with self.subTest(malformed_key=malformed_key):
                scenario = self.valid_scenario()
                scenario[malformed_key] = "<testsuites>"
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 4)
                self.assertIn("malformed structured xUnit", result.stderr)

    def test_dtd_and_entity_xunit_inputs_are_rejected(self) -> None:
        documents = (
            (
                "<!DOCTYPE testsuites SYSTEM "
                "\"file:///private/etc/passwd\">"
                "<testsuites />"
            ),
            (
                "<!DOCTYPE testsuites [<!ENTITY injected \"spoof\">]>"
                "<testsuites><testsuite name=\"&injected;\" /></testsuites>"
            ),
        )
        for document in documents:
            with self.subTest(document=document):
                scenario = self.valid_scenario()
                scenario["runXunitPrimary"] = document
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 4)
                self.assertIn("forbidden DTD/entity", result.stderr)

    def test_duplicate_or_unknown_xunit_id_is_rejected(self) -> None:
        scenarios = (
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runXunitPrimary": self.xunit(
                    self.case("SuiteA"),
                    self.case("SuiteB"),
                ),
                "runXunitSwiftTesting": self.xunit(self.case("SuiteA")),
            },
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runXunitPrimary": self.xunit(
                    self.case("SuiteA"),
                    self.case("SuiteB"),
                    self.case("UnknownSuite"),
                ),
            },
        )
        for scenario in scenarios:
            with self.subTest(scenario=scenario):
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 4)
                self.assertRegex(result.stderr, r"duplicate|unknown")

    def test_display_name_divergence_is_not_treated_as_discovered_test(self) -> None:
        result = self.run_runner(
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runXunitPrimary": self.xunit(
                    self.case("SuiteA", test="A pretty display name"),
                    self.case("SuiteB"),
                ),
            }
        )

        self.assertEqual(result.returncode, 4)
        self.assertIn("unknown structured xUnit test ID", result.stderr)

    def test_test_failure_is_distinct_after_exact_execution_is_proven(self) -> None:
        scenario = self.valid_scenario()
        scenario["runReturncode"] = 1
        scenario["runXunitPrimary"] = self.xunit(
            self.case("SuiteA", outcome="failed")
        )

        result = self.run_runner(scenario)

        self.assertEqual(result.returncode, 5)
        self.assertIn("test failure", result.stderr)

    def test_process_oserror_is_reported_without_traceback(self) -> None:
        bad_bin = self.directory / "bad-bin"
        bad_bin.mkdir()
        (bad_bin / "swift").mkdir()

        result = self.run_runner({}, bin_directory=bad_bin)

        self.assertEqual(result.returncode, 2)
        self.assertIn("swift tool invocation failed", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_list_process_oserror_is_a_discovery_failure(self) -> None:
        result = self.run_runner({"breakAfterMode": "build"})

        self.assertEqual(result.returncode, 3)
        self.assertIn("discovery failure", result.stderr)
        self.assertIn("swift tool invocation failed", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_test_process_oserror_is_a_test_failure(self) -> None:
        result = self.run_runner(
            {
                "breakAfterMode": "list",
                "listStdout": self.list_output("SuiteA", "SuiteB"),
            }
        )

        self.assertEqual(result.returncode, 5)
        self.assertIn("test failure", result.stderr)
        self.assertIn("swift tool invocation failed", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_fresh_output_directory_never_reuses_prior_xunit(self) -> None:
        first = self.run_runner(self.valid_scenario())
        self.assertEqual(first.returncode, 0, first.stderr)

        second = self.run_runner(
            {
                "listStdout": self.list_output("SuiteA", "SuiteB"),
                "runStdout": "Executed 2 tests, with 0 failures\n",
            }
        )

        self.assertEqual(second.returncode, 4)
        self.assertIn("structured xUnit reports are missing", second.stderr)

    def test_runner_builds_once_then_lists_and_executes_without_rebuild(self) -> None:
        result = self.run_runner(self.valid_scenario())

        self.assertEqual(result.returncode, 0, result.stderr)
        invocations = [
            json.loads(line)
            for line in self.log_path.read_text(encoding="utf-8").splitlines()
        ]
        self.assertEqual(len(invocations), 3)
        self.assertEqual(
            invocations[0],
            ["build", "--package-path", str(self.package), "--build-tests"],
        )
        self.assertEqual(
            invocations[1],
            [
                "test",
                "--package-path",
                str(self.package),
                "list",
                "--skip-build",
            ],
        )
        run_arguments = invocations[2]
        self.assertEqual(
            run_arguments[:10],
            [
                "test",
                "--package-path",
                str(self.package),
                "--skip-build",
                "--parallel",
                "--num-workers",
                "1",
                "--filter",
                "SuiteA|SuiteB",
                "--xunit-output",
            ],
        )
        self.assertEqual(len(run_arguments), 11)
        self.assertTrue(run_arguments[10].endswith("/results.xml"))


if __name__ == "__main__":
    unittest.main()
