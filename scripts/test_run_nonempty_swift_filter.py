from __future__ import annotations

import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock
from xml.sax.saxutils import quoteattr

from scripts import run_nonempty_swift_filter as swift_filter


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts" / "run_nonempty_swift_filter.py"


def _wait_for_pid_exit(pid: int, timeout_seconds: float = 2.0) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            return True
        except PermissionError:
            return False
        time.sleep(0.02)
    return False


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
    if scenario.get("replaceXunitDirectoryBeforeReports"):
        original_directory = output.parent
        displaced_directory = original_directory.with_name(
            original_directory.name + "-displaced"
        )
        original_directory.rename(displaced_directory)
        original_directory.mkdir(mode=0o700)
        displaced_directory.rmdir()
    primary = scenario.get("runXunitPrimary")
    if primary is not None:
        output.write_text(primary, encoding="utf-8")
    swift_testing = scenario.get("runXunitSwiftTesting")
    if swift_testing is not None:
        sibling = output.with_name(
            output.stem + "-swift-testing" + output.suffix
        )
        sibling.write_text(swift_testing, encoding="utf-8")
    extra_entry = scenario.get("runExtraXunitEntry")
    if extra_entry is not None:
        (output.parent / "attacker-extra.xml").write_text(
            extra_entry,
            encoding="utf-8",
        )
stdout_hex = scenario.get(mode + "StdoutHex")
if stdout_hex is None:
    sys.stdout.write(scenario.get(mode + "Stdout", ""))
else:
    sys.stdout.flush()
    sys.stdout.buffer.write(bytes.fromhex(stdout_hex))
stderr_hex = scenario.get(mode + "StderrHex")
if stderr_hex is None:
    sys.stderr.write(scenario.get(mode + "Stderr", ""))
else:
    sys.stderr.flush()
    sys.stderr.buffer.write(bytes.fromhex(stderr_hex))
if scenario.get("breakAfterMode") == mode:
    executable = Path(sys.argv[0])
    executable.unlink()
    executable.mkdir()
raise SystemExit(scenario.get(mode + "Returncode", 0))
"""

HANGING_SWIFT = """#!PYTHON!
import os
from pathlib import Path
import signal
import time

parent_path = Path(os.environ["HANGING_SWIFT_PARENT_PID"])
child_path = Path(os.environ["HANGING_SWIFT_CHILD_PID"])
deadline = time.monotonic() + float(
    os.environ.get("HANGING_SWIFT_SELF_LIMIT_SECONDS", "10")
)
parent_path.write_text(str(os.getpid()), encoding="ascii")
child = os.fork()
if child == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    child_path.write_text(str(os.getpid()), encoding="ascii")
    while time.monotonic() < deadline:
        print("descendant still owns the pipe", flush=True)
        time.sleep(0.02)
while time.monotonic() < deadline:
    time.sleep(0.02)
"""


class NonemptySwiftFilterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_directory.cleanup)
        self.directory = Path(self.temp_directory.name).resolve()
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
                body = '<failure message="expected failure" />'
                failures += 1
            else:
                body = ""
            rows.append(
                "    <testcase classname="
                f"{quoteattr(classname)} name={quoteattr(name)}>{body}</testcase>"
            )
        return (
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            "<testsuites>\n"
            f'  <testsuite name="TestResults" tests="{len(cases)}" '
            f'failures="{failures}" skipped="{skipped}">\n'
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
        required_tests: tuple[str, ...] = (),
        bin_directory: Path | None = None,
        path_directory: Path | None = None,
        swift_executable: Path | None = None,
    ) -> subprocess.CompletedProcess[str]:
        self.scenario_path.write_text(
            json.dumps(scenario),
            encoding="utf-8",
        )
        environment = dict(os.environ)
        selected_bin = bin_directory or self.bin_directory
        environment["PATH"] = str(path_directory or selected_bin)
        environment["FAKE_SWIFT_SCENARIO"] = str(self.scenario_path)
        environment["FAKE_SWIFT_LOG"] = str(self.log_path)
        command = [
            sys.executable,
            str(RUNNER),
            "--swift-executable",
            str(swift_executable or selected_bin / "swift"),
            "--package-path",
            str(self.package),
            "--filter",
            filter_value,
        ]
        for suite in required_suites:
            command.extend(["--require-suite", suite])
        for test_id in required_tests:
            command.extend(["--require-test", test_id])
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
            "runXunitSwiftTesting": self.xunit(self.case("SuiteB", test="testExample")),
        }

    def test_timeout_terminates_and_reaps_swift_process_group(self) -> None:
        if not hasattr(os, "fork") or not hasattr(os, "killpg"):
            self.skipTest("process-group descendant test requires POSIX fork/killpg")
        hanging_bin = self.directory / "hanging-bin"
        hanging_bin.mkdir()
        hanging_swift = hanging_bin / "swift"
        hanging_swift.write_text(
            HANGING_SWIFT.replace("#!PYTHON!", f"#!{sys.executable}"),
            encoding="utf-8",
        )
        hanging_swift.chmod(0o755)
        parent_pid_path = self.directory / "hanging-parent.pid"
        child_pid_path = self.directory / "hanging-child.pid"

        def force_cleanup() -> None:
            if not parent_pid_path.exists():
                return
            try:
                os.killpg(
                    int(parent_pid_path.read_text(encoding="ascii")), signal.SIGKILL
                )
            except (ProcessLookupError, PermissionError, ValueError):
                pass

        self.addCleanup(force_cleanup)
        environment = {
            "PATH": str(hanging_bin),
            "HANGING_SWIFT_PARENT_PID": str(parent_pid_path),
            "HANGING_SWIFT_CHILD_PID": str(child_pid_path),
        }
        started = time.monotonic()
        with mock.patch.dict(os.environ, environment, clear=False):
            with self.assertRaisesRegex(
                swift_filter.SwiftInvocationError,
                "timed out",
            ):
                swift_filter.run_swift(
                    ["build"],
                    swift_executable=hanging_swift,
                    timeout_seconds=1.0,
                    termination_grace_seconds=0.10,
                    stdout_limit_bytes=16 * 1024 * 1024,
                    stderr_limit_bytes=16 * 1024 * 1024,
                )
        elapsed = time.monotonic() - started

        self.assertLess(elapsed, 3.0)
        self.assertTrue(parent_pid_path.is_file())
        self.assertTrue(child_pid_path.is_file())
        child_pid = int(child_pid_path.read_text(encoding="ascii"))
        self.assertTrue(
            _wait_for_pid_exit(child_pid),
            "descendant remained after timeout",
        )

    def test_hanging_swift_fixture_has_a_monotonic_self_kill_deadline(self) -> None:
        if not hasattr(os, "fork") or not hasattr(os, "killpg"):
            self.skipTest("self-kill fixture test requires POSIX fork/killpg")
        hanging_swift = self.directory / "self-limiting-swift"
        hanging_swift.write_text(
            HANGING_SWIFT.replace("#!PYTHON!", f"#!{sys.executable}"),
            encoding="utf-8",
        )
        hanging_swift.chmod(0o755)
        parent_pid_path = self.directory / "self-limiting-parent.pid"
        child_pid_path = self.directory / "self-limiting-child.pid"
        environment = {
            **os.environ,
            "HANGING_SWIFT_PARENT_PID": str(parent_pid_path),
            "HANGING_SWIFT_CHILD_PID": str(child_pid_path),
            "HANGING_SWIFT_SELF_LIMIT_SECONDS": "0.20",
        }
        process = subprocess.Popen(
            [str(hanging_swift)],
            env=environment,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )

        try:
            returncode = process.wait(timeout=2.0)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait(timeout=1.0)
            self.fail("hanging Swift fixture exceeded its self-kill deadline")
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=1.0)
            assert process.stdout is not None
            assert process.stderr is not None
            process.stdout.close()
            process.stderr.close()

        self.assertEqual(returncode, 0)
        self.assertTrue(parent_pid_path.is_file())
        self.assertTrue(child_pid_path.is_file())
        child_pid = int(child_pid_path.read_text(encoding="ascii"))
        self.assertTrue(
            _wait_for_pid_exit(child_pid),
            "self-limiting descendant remained alive after its deadline",
        )

    def test_termination_never_reaps_leader_before_final_group_kill(
        self,
    ) -> None:
        events: list[object] = []

        class Stream:
            def close(self) -> None:
                events.append("close")

        class Process:
            pid = 424_245
            stdout = Stream()
            stderr = Stream()

            def wait(self, *, timeout: float) -> int:
                events.append(("wait", timeout))
                return 0

            def kill(self) -> None:
                events.append("kill")

        def observe_killpg(_pid: int, signal_value: int) -> None:
            events.append(("killpg", signal_value))

        with (
            mock.patch.object(
                swift_filter.os,
                "killpg",
                side_effect=observe_killpg,
            ),
            mock.patch.object(
                swift_filter.os,
                "waitid",
                create=True,
                return_value=object(),
            ),
            mock.patch.object(
                swift_filter.time,
                "sleep",
            ),
        ):
            swift_filter.terminate_process_group(
                Process(),
                grace_seconds=0.01,
            )

        kill_index = events.index(("killpg", signal.SIGKILL))
        wait_index = next(
            index
            for index, event in enumerate(events)
            if isinstance(event, tuple) and event[0] == "wait"
        )
        self.assertLess(kill_index, wait_index, events)

    def test_swift_output_cap_plus_one_terminates_process(self) -> None:
        capped_bin = self.directory / "capped-bin"
        capped_bin.mkdir()
        capped_swift = capped_bin / "swift"
        capped_swift.write_text(
            (f"#!{sys.executable}\nimport os\nos.write(1, b'12345')\n"),
            encoding="utf-8",
        )
        capped_swift.chmod(0o755)

        with mock.patch.dict(
            os.environ,
            {"PATH": str(capped_bin)},
            clear=False,
        ):
            with self.assertRaisesRegex(
                swift_filter.SwiftInvocationError,
                "stdout limit",
            ):
                swift_filter.run_swift(
                    ["build"],
                    swift_executable=capped_swift,
                    timeout_seconds=5,
                    stdout_limit_bytes=4,
                    stderr_limit_bytes=1024,
                )

    def test_xunit_equal_size_atomic_replacement_is_rejected(self) -> None:
        report = self.directory / "results.xml"
        report.write_bytes(b"original")
        original_read_bytes = Path.read_bytes
        original_pread = os.pread
        attacked = False

        def replace_report() -> None:
            nonlocal attacked
            if attacked:
                return
            attacked = True
            replacement = self.directory / "replacement.xml"
            replacement.write_bytes(b"replaced")
            os.replace(replacement, report)

        def attacked_read_bytes(path: Path) -> bytes:
            replace_report()
            return original_read_bytes(path)

        def attacked_pread(fd: int, size: int, offset: int) -> bytes:
            raw = original_pread(fd, size, offset)
            replace_report()
            return raw

        with (
            mock.patch.object(Path, "read_bytes", attacked_read_bytes),
            mock.patch.object(swift_filter.os, "pread", attacked_pread),
        ):
            with self.assertRaisesRegex(
                swift_filter.EvidenceError,
                "changed while being read",
            ):
                swift_filter.secure_xunit_bytes(report)

    def test_xunit_symlink_is_rejected(self) -> None:
        target = self.directory / "target.xml"
        target.write_bytes(b"<testsuites />")
        report = self.directory / "results.xml"
        report.symlink_to(target)

        with self.assertRaisesRegex(
            swift_filter.EvidenceError,
            "cannot be opened safely",
        ):
            swift_filter.secure_xunit_bytes(report)

    def test_xunit_hardlink_is_rejected(self) -> None:
        target = self.directory / "target.xml"
        target.write_bytes(b"<testsuites />")
        report = self.directory / "results.xml"
        os.link(target, report)

        with self.assertRaisesRegex(
            swift_filter.EvidenceError,
            "unsafe file metadata",
        ):
            swift_filter.secure_xunit_bytes(report)

    def test_xunit_size_overflow_is_rejected_before_read(self) -> None:
        report = self.directory / "results.xml"
        with report.open("wb") as handle:
            handle.truncate(swift_filter.MAX_XUNIT_BYTES + 1)

        with (
            self.assertRaisesRegex(
                swift_filter.EvidenceError,
                "unsafe file metadata",
            ),
            mock.patch.object(
                swift_filter,
                "bounded_pread",
                side_effect=AssertionError("overflow report was read"),
            ),
        ):
            swift_filter.secure_xunit_bytes(report)

    def test_xunit_in_place_mutation_during_read_is_rejected(self) -> None:
        report = self.directory / "results.xml"
        report.write_bytes(b"original")
        initial = report.stat()
        original_read_bytes = Path.read_bytes
        original_pread = os.pread
        attacked = False

        def mutate_report() -> None:
            nonlocal attacked
            if attacked:
                return
            attacked = True
            with report.open("r+b") as handle:
                handle.write(b"mutated!")
                handle.flush()
                os.fsync(handle.fileno())
            os.utime(
                report,
                ns=(
                    initial.st_atime_ns,
                    initial.st_mtime_ns + 2_000_000_000,
                ),
            )

        def attacked_read_bytes(path: Path) -> bytes:
            raw = original_read_bytes(path)
            mutate_report()
            return raw

        def attacked_pread(fd: int, size: int, offset: int) -> bytes:
            raw = original_pread(fd, size, offset)
            mutate_report()
            return raw

        with (
            mock.patch.object(Path, "read_bytes", attacked_read_bytes),
            mock.patch.object(swift_filter.os, "pread", attacked_pread),
        ):
            with self.assertRaisesRegex(
                swift_filter.EvidenceError,
                "changed while being read",
            ):
                swift_filter.secure_xunit_bytes(report)

    def test_xunit_read_is_bounded_and_never_reopens_the_path(self) -> None:
        report = self.directory / "results.xml"
        expected = b"<testsuites />"
        report.write_bytes(expected)

        with mock.patch.object(
            Path,
            "read_bytes",
            side_effect=AssertionError("unbounded pathname read"),
        ):
            self.assertEqual(
                swift_filter.secure_xunit_bytes(report),
                expected,
            )

    def test_xunit_post_read_fstat_error_is_fail_closed(self) -> None:
        report = self.directory / "results.xml"
        report.write_bytes(b"<testsuites />")
        real_fstat = swift_filter.os.fstat
        calls = 0

        def fail_third_fstat(fd: int):
            nonlocal calls
            calls += 1
            if calls == 3:
                raise OSError("test-only post-read fstat failure")
            return real_fstat(fd)

        with mock.patch.object(
            swift_filter.os,
            "fstat",
            side_effect=fail_third_fstat,
        ):
            with self.assertRaisesRegex(
                swift_filter.EvidenceError,
                "cannot be read safely",
            ):
                swift_filter.secure_xunit_bytes(report)

    def test_closed_alternation_uses_both_xunit_files_and_exact_ids(self) -> None:
        result = self.run_runner(self.valid_scenario())

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("SuiteA=1", result.stdout)
        self.assertIn("SuiteB=1", result.stdout)
        self.assertIn("executed=2", result.stdout)

    def test_one_xunit_report_can_cover_the_complete_closed_execution(self) -> None:
        scenario = {
            "listStdout": self.list_output("SuiteA", "SuiteB"),
            "runXunitPrimary": self.xunit(
                self.case("SuiteA"),
                self.case("SuiteB"),
            ),
        }

        result = self.run_runner(scenario)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("executed=2", result.stdout)

    def test_xunit_directory_rename_recreate_forgery_is_rejected(self) -> None:
        scenario = self.valid_scenario()
        scenario["replaceXunitDirectoryBeforeReports"] = True

        result = self.run_runner(scenario)

        self.assertEqual(result.returncode, 4, result.stderr)
        self.assertIn("structured xUnit directory", result.stderr)

    def test_xunit_output_directory_rejects_unexpected_entries(self) -> None:
        scenario = self.valid_scenario()
        scenario["runExtraXunitEntry"] = "<testsuites />"

        result = self.run_runner(scenario)

        self.assertEqual(result.returncode, 4, result.stderr)
        self.assertIn("unexpected entries", result.stderr)

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

    def test_require_test_parser_rejects_empty_duplicate_or_ambiguous_ids(
        self,
    ) -> None:
        valid = self.discovered_id("SuiteA")
        invalid_sets = (
            ("",),
            (valid, valid),
            ("FixturePackageTests.SuiteA/",),
            ("/testExample",),
            ("SuiteA/testExample",),
            ("FixturePackageTests.SuiteA/test/extra",),
            ("FixturePackageTests.SuiteA/test example",),
            ("FixturePackageTests.SuiteA/test\tcase",),
            ("FixturePackageTests.SuiteA/test\x07case",),
        )
        for required_tests in invalid_sets:
            with self.subTest(required_tests=required_tests):
                result = self.run_runner(
                    self.valid_scenario(),
                    required_tests=required_tests,
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("--require-test", result.stderr)

    def test_required_test_outside_filter_suite_is_invalid(self) -> None:
        result = self.run_runner(
            self.valid_scenario(),
            required_tests=("FixturePackageTests.NotSelected/testExample",),
        )

        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("--require-test", result.stderr)
        self.assertIn("filter-derived suite", result.stderr)

    def test_required_test_with_wrong_resolved_module_is_discovery_failure(
        self,
    ) -> None:
        result = self.run_runner(
            self.valid_scenario(),
            required_tests=("OtherTests.SuiteA/testExample",),
        )

        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("discovery failure", result.stderr)
        self.assertIn("outside the exact resolved suites", result.stderr)

    def test_required_test_missing_from_discovery_is_discovery_failure(
        self,
    ) -> None:
        required_test = self.discovered_id("SuiteA", "testRequiredSentinel")

        result = self.run_runner(
            self.valid_scenario(),
            required_tests=(required_test,),
        )

        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("discovery failure", result.stderr)
        self.assertIn("required test IDs not discovered", result.stderr)
        self.assertIn(required_test, result.stderr)

    def test_required_test_missing_from_execution_is_zero_execution(self) -> None:
        sentinel_name = "testSentinel(argument:value)[case:1]"
        required_test = self.discovered_id("SuiteA", sentinel_name)
        scenario = self.valid_scenario()
        scenario["listStdout"] = (
            self.list_output("SuiteA", "SuiteB") + required_test + "\n"
        )

        result = self.run_runner(
            scenario,
            required_tests=(required_test,),
        )

        self.assertEqual(result.returncode, 4, result.stderr)
        self.assertIn("zero execution", result.stderr)
        self.assertIn("required test IDs missing", result.stderr)
        self.assertIn(required_test, result.stderr)

    def test_repeatable_required_tests_lock_only_explicit_sentinel_subset(
        self,
    ) -> None:
        sentinel_name = "testSentinel(argument:value)[case:1]"
        suite_a_sentinel = self.discovered_id("SuiteA", sentinel_name)
        suite_b_sentinel = self.discovered_id("SuiteB")
        scenario = {
            "listStdout": (
                self.list_output("SuiteA", "SuiteB") + suite_a_sentinel + "\n"
            ),
            "runXunitPrimary": self.xunit(
                self.case("SuiteA"),
                self.case("SuiteA", test=sentinel_name),
            ),
            "runXunitSwiftTesting": self.xunit(self.case("SuiteB")),
        }

        result = self.run_runner(
            scenario,
            required_tests=(suite_a_sentinel, suite_b_sentinel),
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("executed=3", result.stdout)

    def test_closed_filter_rejects_regex_operators_and_empty_or_duplicate_terms(
        self,
    ) -> None:
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
                "listStdout": (self.list_output("SuiteA", "NotSuiteB")),
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

    def test_missing_primary_or_swift_testing_report_cannot_hide_expected_id(
        self,
    ) -> None:
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

    def test_malformed_xunit_testcase_diagnostic_names_the_report(self) -> None:
        raw = (
            b'<testsuites><testcase classname="FixturePackageTests.SuiteA" '
            b'name=" bad " /></testsuites>'
        )

        with self.assertRaisesRegex(
            swift_filter.EvidenceError,
            r"malformed structured xUnit testcase in primary\.xml",
        ):
            swift_filter.parse_xunit_bytes(raw, "primary.xml")

    def test_dtd_and_entity_xunit_inputs_are_rejected(self) -> None:
        documents = (
            ('<!DOCTYPE testsuites SYSTEM "file:///private/etc/passwd"><testsuites />'),
            (
                '<!DOCTYPE testsuites [<!ENTITY injected "spoof">]>'
                '<testsuites><testsuite name="&injected;" /></testsuites>'
            ),
        )
        for document in documents:
            with self.subTest(document=document):
                scenario = self.valid_scenario()
                scenario["runXunitPrimary"] = document
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 4)
                self.assertIn("forbidden DTD/entity", result.stderr)

    def test_non_utf8_or_bom_xunit_cannot_hide_dtd_or_entity(self) -> None:
        document = (
            '<?xml version="1.0"?>'
            '<!DOCTYPE testsuites [<!ENTITY injected "spoof">]>'
            "<testsuites />"
        )
        encodings = ("utf-16", "utf-32")
        for encoding in encodings:
            with self.subTest(encoding=encoding):
                with self.assertRaisesRegex(
                    swift_filter.EvidenceError,
                    "strict UTF-8 without BOM",
                ):
                    swift_filter.parse_xunit_bytes(
                        document.encode(encoding),
                        f"{encoding}.xml",
                    )
        with self.assertRaisesRegex(
            swift_filter.EvidenceError,
            "strict UTF-8 without BOM",
        ):
            swift_filter.parse_xunit_bytes(
                b"\xef\xbb\xbf<testsuites />",
                "utf8-bom.xml",
            )
        with self.assertRaisesRegex(
            swift_filter.EvidenceError,
            "must declare UTF-8 encoding",
        ):
            swift_filter.parse_xunit_bytes(
                (b'<?xml version="1.0" encoding="UTF-16"?><testsuites />'),
                "mismatched-declaration.xml",
            )

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
        scenario["runXunitPrimary"] = self.xunit(self.case("SuiteA", outcome="failed"))

        result = self.run_runner(scenario)

        self.assertEqual(result.returncode, 5)
        self.assertIn("test failure", result.stderr)

    def test_invalid_utf8_discovery_is_controlled_and_fail_closed(self) -> None:
        result = self.run_runner(
            {
                "listStdoutHex": "ff0a",
            }
        )

        self.assertEqual(result.returncode, 3)
        self.assertIn("discovery failure", result.stderr)
        self.assertIn("UTF-8", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_invalid_utf8_build_diagnostics_are_replayed_with_replacement(
        self,
    ) -> None:
        result = self.run_runner(
            {
                "buildStderrHex": "ff0a",
                "buildReturncode": 1,
            }
        )

        self.assertEqual(result.returncode, 2)
        self.assertIn("\ufffd", result.stderr)
        self.assertIn("build failure", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_invalid_utf8_test_diagnostics_are_replayed_with_replacement(
        self,
    ) -> None:
        scenario = self.valid_scenario()
        scenario["runStderrHex"] = "ff0a"
        scenario["runReturncode"] = 1
        scenario["runXunitPrimary"] = self.xunit(self.case("SuiteA", outcome="failed"))

        result = self.run_runner(scenario)

        self.assertEqual(result.returncode, 5)
        self.assertIn("\ufffd", result.stderr)
        self.assertIn("test failure", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_nonregular_swift_executable_is_invalid_without_traceback(self) -> None:
        bad_bin = self.directory / "bad-bin"
        bad_bin.mkdir()
        (bad_bin / "swift").mkdir()

        result = self.run_runner({}, bin_directory=bad_bin)

        self.assertEqual(result.returncode, 1)
        self.assertIn("--swift-executable", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_swift_executable_rejects_relative_symlink_and_nonexecutable_paths(
        self,
    ) -> None:
        symlink = self.directory / "swift-link"
        symlink.symlink_to(self.fake_swift)
        nonexecutable = self.directory / "swift-not-executable"
        nonexecutable.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        cases = (Path("swift"), symlink, nonexecutable)

        for executable in cases:
            with self.subTest(executable=executable):
                result = self.run_runner(
                    self.valid_scenario(),
                    swift_executable=executable,
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("--swift-executable", result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_explicit_swift_executable_ignores_poisoned_path(self) -> None:
        poisoned_path = self.directory / "poisoned-path"
        poisoned_path.mkdir()
        poison = poisoned_path / "swift"
        poison.write_text("#!/bin/sh\nexit 97\n", encoding="utf-8")
        poison.chmod(0o755)

        result = self.run_runner(
            self.valid_scenario(),
            path_directory=poisoned_path,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("executed=2", result.stdout)

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
