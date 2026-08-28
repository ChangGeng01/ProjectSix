from __future__ import annotations

import copy
import contextlib
import importlib
import io
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
import uuid
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts" / "run_nonempty_xcode_test.py"


FAKE_XCODEBUILD = """#!PYTHON!
import json
import os
from pathlib import Path
import signal
import stat
import sys
import time

fixture = Path(__file__).resolve().parent.parent
scenario = json.loads((fixture / "scenario.json").read_text())
arguments = sys.argv[1:]
home = Path(os.environ["HOME"])
temporary = Path(os.environ["TMPDIR"])
with (fixture / "tool-log.jsonl").open("a", encoding="utf-8") as handle:
    handle.write(json.dumps({
        "tool": "xcodebuild",
        "cwd": os.getcwd(),
        "arguments": arguments,
        "environment": dict(os.environ),
        "runtimeDirectories": {
            "home": str(home),
            "homeIdentity": [home.stat().st_dev, home.stat().st_ino],
            "homeMode": stat.S_IMODE(home.stat().st_mode),
            "temporary": str(temporary),
            "temporaryIdentity": [temporary.stat().st_dev, temporary.stat().st_ino],
            "temporaryMode": stat.S_IMODE(temporary.stat().st_mode),
        },
        "stdinWasEOF": sys.stdin.buffer.read(1) == b"",
    }, sort_keys=True) + "\\n")

if scenario.get("zeroExitLeaderWithLiveDescendant"):
    ready_read, ready_write = os.pipe()
    child = os.fork()
    if child == 0:
        os.close(ready_read)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        (fixture / "orphan-child.pid").write_text(
            str(os.getpid()), encoding="ascii"
        )
        os.close(sys.stdout.fileno())
        os.close(sys.stderr.fileno())
        os.write(ready_write, b"1")
        os.close(ready_write)
        time.sleep(3.0)
        (fixture / "orphan-survival.marker").write_text(
            "descendant-survived", encoding="ascii"
        )
        os._exit(0)
    os.close(ready_write)
    os.read(ready_read, 1)
    os.close(ready_read)
    os._exit(0)

if scenario.get("hangXcodebuild"):
    (fixture / "xcode-parent.pid").write_text(
        str(os.getpid()), encoding="ascii"
    )
    ready_read, ready_write = os.pipe()
    child = os.fork()
    if child == 0:
        os.close(ready_read)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        (fixture / "xcode-child.pid").write_text(
            str(os.getpid()), encoding="ascii"
        )
        os.write(ready_write, b"1")
        os.close(ready_write)
        while True:
            time.sleep(0.02)
    os.close(ready_write)
    os.read(ready_read, 1)
    os.close(ready_read)
    while True:
        time.sleep(0.02)

derived = Path(arguments[arguments.index("-derivedDataPath") + 1])
result = Path(arguments[arguments.index("-resultBundlePath") + 1])
replacement = scenario.get("replaceOutputParentWithSymlink")
if replacement:
    original_parent = (derived if replacement == "derived" else result).parent
    displaced_parent = original_parent.with_name(original_parent.name + "-held")
    original_parent.rename(displaced_parent)
    target = fixture / "substitution-target"
    target.mkdir()
    original_parent.symlink_to(target, target_is_directory=True)
if not scenario.get("omitDerivedData"):
    derived.mkdir()
    (derived / "BuildRecord").write_text("fresh", encoding="utf-8")
if not scenario.get("omitResultBundle"):
    if scenario.get("symlinkResultBundle"):
        target = fixture / "substitution-target"
        target.mkdir()
        result.symlink_to(target, target_is_directory=True)
    else:
        result.mkdir()
        if not scenario.get("emptyResultBundle"):
            (result / "Info.plist").write_text("fresh", encoding="utf-8")
raise SystemExit(scenario.get("xcodebuildReturncode", 0))
"""


FAKE_XCRESULTTOOL = """#!PYTHON!
import json
import os
from pathlib import Path
import stat
import sys

fixture = Path(__file__).resolve().parent.parent
scenario = json.loads((fixture / "scenario.json").read_text())
arguments = sys.argv[1:]
home = Path(os.environ["HOME"])
temporary = Path(os.environ["TMPDIR"])
with (fixture / "tool-log.jsonl").open("a", encoding="utf-8") as handle:
    handle.write(json.dumps({
        "tool": "xcresulttool",
        "cwd": os.getcwd(),
        "arguments": arguments,
        "environment": dict(os.environ),
        "runtimeDirectories": {
            "home": str(home),
            "homeIdentity": [home.stat().st_dev, home.stat().st_ino],
            "homeMode": stat.S_IMODE(home.stat().st_mode),
            "temporary": str(temporary),
            "temporaryIdentity": [temporary.stat().st_dev, temporary.stat().st_ino],
            "temporaryMode": stat.S_IMODE(temporary.stat().st_mode),
        },
        "stdinWasEOF": sys.stdin.buffer.read(1) == b"",
    }, sort_keys=True) + "\\n")
mode = arguments[arguments.index("test-results") + 1]
raw_override = scenario.get(mode + "Raw")
if raw_override is not None:
    sys.stdout.write(raw_override)
else:
    sys.stdout.write(json.dumps(
        scenario[mode], sort_keys=True, separators=(",", ":")
    ))
if scenario.get("replaceRuntimeDirectoryAfterSurface") == mode:
    anchor = home.parent
    anchor.chmod(0o700)
    home.rename(home.with_name("home-held"))
    home.mkdir(mode=0o700)
    anchor.chmod(0o500)
raise SystemExit(scenario.get(mode + "Returncode", 0))
"""


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


class NonemptyXcodeTestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.directory = Path(self.temporary_directory.name).resolve()
        self.package = self.directory / "FixturePackage"
        self.package.mkdir()
        (self.package / "Package.swift").write_text(
            "// swift-tools-version: 6.0\n",
            encoding="utf-8",
        )
        self.bin_directory = self.directory / "bin"
        self.bin_directory.mkdir()
        for name, source in (
            ("xcodebuild", FAKE_XCODEBUILD),
            ("xcresulttool", FAKE_XCRESULTTOOL),
        ):
            executable = self.bin_directory / name
            executable.write_text(
                source.replace("#!PYTHON!", f"#!{sys.executable}"),
                encoding="utf-8",
            )
            executable.chmod(0o755)
        self.fake_xcodebuild = self.bin_directory / "xcodebuild"
        self.fake_xcresulttool = self.bin_directory / "xcresulttool"
        self.scenario_path = self.directory / "scenario.json"
        self.log_path = self.directory / "tool-log.jsonl"
        self.parent_pid_path = self.directory / "xcode-parent.pid"
        self.child_pid_path = self.directory / "xcode-child.pid"
        self.orphan_child_pid_path = self.directory / "orphan-child.pid"
        self.orphan_marker_path = self.directory / "orphan-survival.marker"
        self.symlink_target = self.directory / "substitution-target"
        self.output_parent = self.directory / "fresh-output-parent"
        self.output_parent.mkdir()
        self.derived_data = self.output_parent / "DerivedData"
        self.result_bundle = self.output_parent / "Result.xcresult"

    def force_cleanup_orphan_group(self) -> None:
        if not self.orphan_child_pid_path.exists():
            return
        try:
            child_pid = int(self.orphan_child_pid_path.read_text(encoding="ascii"))
            process_group_id = os.getpgid(child_pid)
        except (OSError, ValueError):
            return
        if process_group_id == os.getpgrp():
            raise AssertionError("fixture descendant joined the test process group")
        try:
            os.killpg(process_group_id, signal.SIGKILL)
        except (PermissionError, ProcessLookupError):
            pass

    @staticmethod
    def valid_summary() -> dict:
        return {
            "title": "Test - FixturePackage",
            "startTime": 1000.0,
            "finishTime": 1002.5,
            "environmentDescription": "FixturePackage · iOS Simulator",
            "topInsights": [],
            "result": "Passed",
            "totalTestCount": 2,
            "passedTests": 2,
            "failedTests": 0,
            "skippedTests": 0,
            "expectedFailures": 0,
            "statistics": [],
            "devicesAndConfigurations": [],
            "testFailures": [],
            "runtimeWarnings": [],
        }

    @staticmethod
    def case_node(name: str, result: str = "Passed") -> dict:
        return {
            "nodeIdentifier": f"FixtureSuite/{name}",
            "nodeIdentifierURL": (
                "test://com.apple.xcode/Fixture/FixtureTests/FixtureSuite/" + name
            ),
            "nodeType": "Test Case",
            "name": name,
            "duration": "0.01s",
            "durationInSeconds": 0.01,
            "result": result,
        }

    @classmethod
    def valid_tests(cls) -> dict:
        return {
            "testPlanConfigurations": [
                {
                    "configurationId": "1",
                    "configurationName": "Test Scheme Action",
                }
            ],
            "devices": [
                {
                    "deviceId": "SIM-1",
                    "deviceName": "iPhone",
                    "architecture": "arm64",
                    "modelName": "iPhone",
                    "platform": "iOS Simulator",
                    "osVersion": "27.0",
                    "osBuildNumber": "24A1",
                }
            ],
            "testNodes": [
                {
                    "nodeType": "Test Plan",
                    "name": "FixturePackage",
                    "result": "Passed",
                    "children": [
                        {
                            "nodeType": "Unit test bundle",
                            "name": "FixtureTests",
                            "result": "Passed",
                            "children": [
                                {
                                    "nodeType": "Test Suite",
                                    "name": "FixtureSuite",
                                    "result": "Passed",
                                    "children": [
                                        cls.case_node("testOne()"),
                                        cls.case_node("testTwo()"),
                                    ],
                                }
                            ],
                        }
                    ],
                }
            ],
        }

    def valid_scenario(self) -> dict:
        return {
            "summary": self.valid_summary(),
            "tests": self.valid_tests(),
        }

    def run_runner(
        self,
        scenario: dict,
        *,
        package_path: Path | str | None = None,
        derived_data_path: Path | str | None = None,
        result_bundle_path: Path | str | None = None,
        targets: tuple[str, ...] = ("FixtureTests",),
        timeout_seconds: float | None = None,
        xcodebuild_executable: Path | str | None = None,
        xcresulttool_executable: Path | str | None = None,
        path_directory: Path | None = None,
        extra_arguments: tuple[str, ...] = (),
        outer_stdin: str = "nonempty-outer-stdin-must-not-reach-tools",
        restrictive_umask: bool = False,
    ) -> subprocess.CompletedProcess[str]:
        self.scenario_path.write_text(
            json.dumps(scenario),
            encoding="utf-8",
        )
        environment = {
            "PATH": str(path_directory or self.bin_directory),
            "QINAO_CREDENTIAL_SENTINEL": "must-not-reach-tools",
            "AWS_SECRET_ACCESS_KEY": "must-not-reach-tools-either",
        }
        command = [
            sys.executable,
            str(RUNNER),
            "--xcodebuild-executable",
            str(xcodebuild_executable or self.fake_xcodebuild),
            "--xcresulttool-executable",
            str(xcresulttool_executable or self.fake_xcresulttool),
            "--package-path",
            str(package_path if package_path is not None else self.package),
            "--scheme",
            "Fixture",
            "--destination",
            "platform=iOS Simulator,id=SIM-1",
            "--derived-data-path",
            str(
                derived_data_path
                if derived_data_path is not None
                else self.derived_data
            ),
            "--result-bundle-path",
            str(
                result_bundle_path
                if result_bundle_path is not None
                else self.result_bundle
            ),
        ]
        for target in targets:
            command.extend(["--require-target", target])
        if timeout_seconds is not None:
            command.extend(["--timeout-seconds", str(timeout_seconds)])
        command.extend(extra_arguments)
        return subprocess.run(
            command,
            cwd=ROOT,
            env=environment,
            input=outer_stdin,
            capture_output=True,
            text=True,
            check=False,
            timeout=8,
            preexec_fn=(lambda: os.umask(0o777)) if restrictive_umask else None,
        )

    def tool_log(self) -> list[dict]:
        return [
            json.loads(line)
            for line in self.log_path.read_text(encoding="utf-8").splitlines()
        ]

    @staticmethod
    def substitute_descriptor(
        binding: object,
        attribute: str,
        replacement_fd: int,
    ) -> None:
        original_fd = getattr(binding, attribute)
        if original_fd == replacement_fd:
            raise AssertionError("replacement descriptor unexpectedly aliases original")
        os.close(original_fd)
        os.dup2(replacement_fd, original_fd)
        os.close(replacement_fd)

    def test_success_uses_closed_commands_structured_evidence_and_cleanup(
        self,
    ) -> None:
        result = self.run_runner(self.valid_scenario())

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(
            result.stdout,
            r"\Axcode-test: PASS target=FixtureTests discovered=2 "
            r"executed=2 evidence-sha256=[0-9a-f]{64}\n\Z",
        )
        self.assertEqual(result.stderr, "")
        self.assertFalse(self.derived_data.exists())
        self.assertFalse(self.result_bundle.exists())
        calls = self.tool_log()
        self.assertEqual(len(calls), 3)
        self.assertEqual(calls[0]["tool"], "xcodebuild")
        self.assertEqual(calls[0]["cwd"], str(self.package))
        xcode_arguments = calls[0]["arguments"]
        self.assertEqual(
            xcode_arguments[:5],
            [
                "test",
                "-scheme",
                "Fixture",
                "-destination",
                "platform=iOS Simulator,id=SIM-1",
            ],
        )
        self.assertEqual(xcode_arguments[-1], "-only-testing:FixtureTests")
        derived_argument = Path(
            xcode_arguments[xcode_arguments.index("-derivedDataPath") + 1]
        )
        result_argument = Path(
            xcode_arguments[xcode_arguments.index("-resultBundlePath") + 1]
        )
        self.assertEqual(derived_argument.name, self.derived_data.name)
        self.assertEqual(result_argument.name, self.result_bundle.name)
        self.assertNotEqual(derived_argument, self.derived_data)
        self.assertNotEqual(result_argument, self.result_bundle)
        self.assertIn(self.derived_data, derived_argument.parents)
        self.assertIn(self.result_bundle, result_argument.parents)
        runtime_identity: tuple[tuple[int, int], tuple[int, int]] | None = None
        for call, surface in zip(calls[1:], ("summary", "tests")):
            self.assertEqual(call["tool"], "xcresulttool")
            self.assertEqual(call["cwd"], str(self.package))
            self.assertEqual(
                call["arguments"],
                [
                    "get",
                    "test-results",
                    surface,
                    "--schema-version",
                    "0.4.0",
                    "--path",
                    str(result_argument),
                    "--compact",
                ],
            )

        for call in calls:
            self.assertEqual(
                set(call["environment"]),
                {
                    "HOME",
                    "LANG",
                    "LC_ALL",
                    "PATH",
                    "TMPDIR",
                    "__CF_USER_TEXT_ENCODING",
                },
            )
            self.assertNotIn("QINAO_CREDENTIAL_SENTINEL", call["environment"])
            self.assertNotIn("AWS_SECRET_ACCESS_KEY", call["environment"])
            self.assertNotIn("must-not-reach-tools", json.dumps(call))
            self.assertEqual(
                call["environment"]["PATH"],
                "/usr/bin:/bin:/usr/sbin:/sbin",
            )
            self.assertEqual(Path(call["environment"]["HOME"]).name, "home")
            self.assertEqual(
                Path(call["environment"]["TMPDIR"]).name,
                "tmp",
            )
            runtime = call["runtimeDirectories"]
            home = Path(runtime["home"])
            temporary = Path(runtime["temporary"])
            self.assertEqual(home.parent, temporary.parent)
            self.assertEqual(home.parent, derived_argument.parents[1])
            self.assertEqual(runtime["homeMode"], 0o700)
            self.assertEqual(runtime["temporaryMode"], 0o700)
            identity = (
                tuple(runtime["homeIdentity"]),
                tuple(runtime["temporaryIdentity"]),
            )
            self.assertNotEqual(identity[0], identity[1])
            if runtime_identity is None:
                runtime_identity = identity
            self.assertEqual(identity, runtime_identity)
            self.assertTrue(call["stdinWasEOF"])

    def test_private_runtime_directories_ignore_restrictive_parent_umask(
        self,
    ) -> None:
        result = self.run_runner(
            self.valid_scenario(),
            restrictive_umask=True,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        for call in self.tool_log():
            runtime = call["runtimeDirectories"]
            self.assertEqual(runtime["homeMode"], 0o700)
            self.assertEqual(runtime["temporaryMode"], 0o700)
            self.assertTrue(call["stdinWasEOF"])

    def test_explicit_tools_ignore_poisoned_path(self) -> None:
        poisoned_path = self.directory / "poisoned-path"
        poisoned_path.mkdir()
        for name in ("xcodebuild", "xcresulttool", "xcrun"):
            poison = poisoned_path / name
            poison.write_text("#!/bin/sh\nexit 97\n", encoding="utf-8")
            poison.chmod(0o755)

        result = self.run_runner(
            self.valid_scenario(),
            path_directory=poisoned_path,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [call["tool"] for call in self.tool_log()],
            ["xcodebuild", "xcresulttool", "xcresulttool"],
        )

    def test_tool_executables_reject_relative_symlink_and_nonexecutable_paths(
        self,
    ) -> None:
        xcodebuild_link = self.directory / "xcodebuild-link"
        xcodebuild_link.symlink_to(self.fake_xcodebuild)
        xcresulttool_link = self.directory / "xcresulttool-link"
        xcresulttool_link.symlink_to(self.fake_xcresulttool)
        nonexecutable = self.directory / "not-executable"
        nonexecutable.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        cases = (
            ("xcodebuild", self.fake_xcresulttool),
            (xcodebuild_link, self.fake_xcresulttool),
            (nonexecutable, self.fake_xcresulttool),
            (self.fake_xcodebuild, "xcresulttool"),
            (self.fake_xcodebuild, xcresulttool_link),
            (self.fake_xcodebuild, nonexecutable),
        )

        for xcodebuild, xcresulttool in cases:
            with self.subTest(
                xcodebuild=xcodebuild,
                xcresulttool=xcresulttool,
            ):
                result = self.run_runner(
                    self.valid_scenario(),
                    xcodebuild_executable=xcodebuild,
                    xcresulttool_executable=xcresulttool,
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertRegex(
                    result.stderr,
                    r"--(?:xcodebuild|xcresulttool)-executable",
                )
                self.assertNotIn("Traceback", result.stderr)

    def test_requires_exactly_one_nonempty_target(self) -> None:
        for targets in ((), ("",), ("FixtureTests", "OtherTests")):
            with self.subTest(targets=targets):
                result = self.run_runner(
                    self.valid_scenario(),
                    targets=targets,
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("require-target", result.stderr)

    def test_rejects_every_duplicate_singleton_and_option_abbreviation(self) -> None:
        duplicate_values = (
            ("--xcodebuild-executable", str(self.fake_xcodebuild)),
            ("--xcresulttool-executable", str(self.fake_xcresulttool)),
            ("--package-path", str(self.package)),
            ("--scheme", "Fixture"),
            ("--destination", "platform=iOS Simulator,id=SIM-1"),
            ("--derived-data-path", str(self.derived_data)),
            ("--result-bundle-path", str(self.result_bundle)),
            ("--require-target", "FixtureTests"),
            ("--timeout-seconds", "1"),
        )
        for option, value in duplicate_values:
            with self.subTest(option=option):
                timeout = 1.0 if option == "--timeout-seconds" else None
                result = self.run_runner(
                    self.valid_scenario(),
                    timeout_seconds=timeout,
                    extra_arguments=(option, value),
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("must appear at most once", result.stderr)
                self.assertFalse(self.log_path.exists())

        abbreviated = self.run_runner(
            self.valid_scenario(),
            extra_arguments=("--sche", "Alias"),
        )
        self.assertEqual(abbreviated.returncode, 1, abbreviated.stderr)
        self.assertIn("unrecognized arguments", abbreviated.stderr)
        self.assertFalse(self.log_path.exists())

    def test_rejects_nonabsolute_repository_local_or_overlapping_roots(
        self,
    ) -> None:
        local_name = f".forbidden-xcode-root-{uuid.uuid4().hex}"
        cases = (
            ("relative-derived", self.result_bundle),
            (ROOT / local_name, self.result_bundle),
            (self.derived_data, ROOT / local_name),
            (self.output_parent / "Nested", self.output_parent / "Nested/R"),
        )
        for derived, result_bundle in cases:
            with self.subTest(derived=derived, result_bundle=result_bundle):
                result = self.run_runner(
                    self.valid_scenario(),
                    derived_data_path=derived,
                    result_bundle_path=result_bundle,
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("fresh repository-external", result.stderr)
                self.assertFalse((ROOT / local_name).exists())

    def test_rejects_preexisting_or_symlinked_roots_without_cleanup(self) -> None:
        preexisting = self.output_parent / "preexisting"
        preexisting.mkdir()
        symlink_target = self.output_parent / "real-parent"
        symlink_target.mkdir()
        symlink_path = self.output_parent / "linked-derived"
        symlink_path.symlink_to(symlink_target, target_is_directory=True)
        linked_parent = self.output_parent / "linked-parent"
        linked_parent.symlink_to(symlink_target, target_is_directory=True)
        cases = (
            (preexisting, self.result_bundle),
            (self.derived_data, preexisting),
            (symlink_path, self.result_bundle),
            (linked_parent / "fresh-child", self.result_bundle),
        )
        for derived, result_bundle in cases:
            with self.subTest(derived=derived, result_bundle=result_bundle):
                result = self.run_runner(
                    self.valid_scenario(),
                    derived_data_path=derived,
                    result_bundle_path=result_bundle,
                )
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("fresh repository-external", result.stderr)
        self.assertTrue(preexisting.is_dir())
        self.assertTrue(symlink_path.is_symlink())
        self.assertTrue(symlink_target.is_dir())

    def test_exit_zero_with_missing_empty_or_symlinked_bundle_fails_closed(
        self,
    ) -> None:
        for mutation in (
            "omitResultBundle",
            "emptyResultBundle",
            "symlinkResultBundle",
            "omitDerivedData",
        ):
            with self.subTest(mutation=mutation):
                scenario = self.valid_scenario()
                scenario[mutation] = True
                result = self.run_runner(scenario)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertRegex(result.stderr, r"evidence failure|cleanup failure")
                self.assertNotIn("PASS", result.stdout)

    def test_zero_tests_wrong_target_or_second_target_fails_closed(self) -> None:
        scenarios: list[dict] = []
        zero = self.valid_scenario()
        zero["summary"]["totalTestCount"] = 0
        zero["summary"]["passedTests"] = 0
        zero["tests"]["testNodes"][0]["children"][0]["children"] = []
        scenarios.append(zero)

        wrong = self.valid_scenario()
        wrong["tests"]["testNodes"][0]["children"][0]["name"] = "WrongTests"
        scenarios.append(wrong)

        second = self.valid_scenario()
        second_bundle = copy.deepcopy(second["tests"]["testNodes"][0]["children"][0])
        second_bundle["name"] = "OtherTests"
        second["tests"]["testNodes"][0]["children"].append(second_bundle)
        scenarios.append(second)

        stray = self.valid_scenario()
        stray["tests"]["testNodes"][0]["children"].append(
            self.case_node("testOutsideRequiredTarget()")
        )
        scenarios.append(stray)

        for scenario in scenarios:
            with self.subTest(scenario=scenario):
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 3, result.stderr)
                self.assertIn("evidence failure", result.stderr)
                self.assertFalse(self.derived_data.exists())
                self.assertFalse(self.result_bundle.exists())

    def test_failed_skipped_expected_failure_or_incomplete_action_is_rejected(
        self,
    ) -> None:
        scenarios: list[dict] = []
        for result_name, summary_field in (
            ("Failed", "failedTests"),
            ("Skipped", "skippedTests"),
            ("Expected Failure", "expectedFailures"),
        ):
            scenario = self.valid_scenario()
            scenario["summary"]["passedTests"] = 1
            scenario["summary"][summary_field] = 1
            scenario["summary"]["result"] = (
                "Failed" if result_name == "Failed" else "Passed"
            )
            cases = scenario["tests"]["testNodes"][0]["children"][0]["children"][0][
                "children"
            ]
            cases[1]["result"] = result_name
            scenarios.append(scenario)

        no_finish = self.valid_scenario()
        del no_finish["summary"]["finishTime"]
        scenarios.append(no_finish)

        incomplete_plan = self.valid_scenario()
        incomplete_plan["tests"]["testNodes"][0]["result"] = "unknown"
        scenarios.append(incomplete_plan)

        for scenario in scenarios:
            with self.subTest(scenario=scenario):
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 3, result.stderr)
                self.assertIn("evidence failure", result.stderr)

    def test_summary_counts_must_close_exactly_with_passed_test_case_tree(
        self,
    ) -> None:
        passed_exceeds_total = self.valid_scenario()
        passed_exceeds_total["summary"]["passedTests"] = 3

        tree_has_fewer_cases = self.valid_scenario()
        cases = tree_has_fewer_cases["tests"]["testNodes"][0]["children"][0][
            "children"
        ][0]["children"]
        cases.pop()

        summary_has_more_cases = self.valid_scenario()
        summary_has_more_cases["summary"]["totalTestCount"] = 3
        summary_has_more_cases["summary"]["passedTests"] = 3

        for scenario in (
            passed_exceeds_total,
            tree_has_fewer_cases,
            summary_has_more_cases,
        ):
            with self.subTest(summary=scenario["summary"]):
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 3, result.stderr)
                self.assertIn("evidence failure", result.stderr)
                self.assertNotIn("PASS", result.stdout)

    def test_malformed_or_failed_xcresulttool_is_not_structured_evidence(
        self,
    ) -> None:
        malformed = self.valid_scenario()
        malformed["summaryRaw"] = "not-json"
        failed_tool = self.valid_scenario()
        failed_tool["testsReturncode"] = 7
        duplicate_key = self.valid_scenario()
        duplicate_key["summaryRaw"] = json.dumps(
            duplicate_key["summary"],
            sort_keys=True,
            separators=(",", ":"),
        ).replace(
            '"result":"Passed"',
            '"result":"Failed","result":"Passed"',
            1,
        )
        for scenario in (malformed, failed_tool, duplicate_key):
            with self.subTest(scenario=scenario):
                result = self.run_runner(scenario)
                self.assertEqual(result.returncode, 3, result.stderr)
                self.assertIn("evidence failure", result.stderr)
                self.assertNotIn("Traceback", result.stderr)

    def test_runtime_directory_drift_between_xcresult_surfaces_fails_closed(
        self,
    ) -> None:
        scenario = self.valid_scenario()
        scenario["replaceRuntimeDirectoryAfterSurface"] = "summary"

        result = self.run_runner(scenario)

        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("evidence failure", result.stderr)
        self.assertIn("home", result.stderr)
        self.assertNotIn("PASS", result.stdout)
        self.assertEqual(
            [call["tool"] for call in self.tool_log()],
            ["xcodebuild", "xcresulttool"],
        )

    def test_prewrite_parent_substitution_is_denied_with_zero_substitute_writes(
        self,
    ) -> None:
        for output_kind in ("derived", "result"):
            with self.subTest(output_kind=output_kind):
                scenario = self.valid_scenario()
                scenario["replaceOutputParentWithSymlink"] = output_kind

                result = self.run_runner(scenario)

                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("xcodebuild failure", result.stderr)
                self.assertFalse(self.symlink_target.exists())
                self.assertFalse(self.derived_data.exists())
                self.assertFalse(self.result_bundle.exists())

    def test_parent_descriptor_identity_substitution_is_rejected(self) -> None:
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        binding = module.create_secure_output_root(
            self.derived_data,
            "--derived-data-path",
        )
        replacement_parent = self.directory / "replacement-parent"
        replacement_parent.mkdir(mode=0o700)
        replacement_fd = os.open(
            replacement_parent,
            module.directory_open_flags(),
        )
        os.fchmod(binding.anchor_fd, 0o700)
        os.rename(
            binding.anchor_name,
            binding.anchor_name,
            src_dir_fd=binding.parent_fd,
            dst_dir_fd=replacement_fd,
        )
        os.fchmod(binding.anchor_fd, 0o500)
        self.substitute_descriptor(binding, "parent_fd", replacement_fd)
        try:
            with self.assertRaisesRegex(
                module.ValidationError,
                "parent descriptor identity",
            ):
                module.require_secure_output_binding(
                    binding,
                    require_output_missing=True,
                )
        finally:
            module.cleanup_secure_output_root(binding)

    def test_anchor_descriptor_identity_substitution_is_rejected(self) -> None:
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        binding = module.create_secure_output_root(
            self.derived_data,
            "--derived-data-path",
        )
        replacement_anchor = self.directory / "replacement-anchor"
        replacement_anchor.mkdir(mode=0o700)
        replacement_fd = os.open(
            replacement_anchor,
            module.directory_open_flags(),
        )
        os.fchmod(binding.anchor_fd, 0o700)
        for name in ("payload", "home", "tmp"):
            os.rename(
                name,
                name,
                src_dir_fd=binding.anchor_fd,
                dst_dir_fd=replacement_fd,
            )
        os.fchmod(binding.anchor_fd, 0o500)
        self.substitute_descriptor(binding, "anchor_fd", replacement_fd)
        try:
            with self.assertRaisesRegex(
                module.ValidationError,
                "anchor descriptor identity",
            ):
                module.require_secure_output_binding(
                    binding,
                    require_output_missing=True,
                )
        finally:
            module.cleanup_secure_output_root(binding)

    def test_payload_descriptor_identity_substitution_is_rejected(self) -> None:
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        binding = module.create_secure_output_root(
            self.derived_data,
            "--derived-data-path",
        )
        replacement_payload = self.directory / "replacement-payload"
        replacement_payload.mkdir(mode=0o700)
        replacement_fd = os.open(
            replacement_payload,
            module.directory_open_flags(),
        )
        self.substitute_descriptor(binding, "payload_fd", replacement_fd)
        try:
            with self.assertRaisesRegex(
                module.ValidationError,
                "payload descriptor identity",
            ):
                module.require_secure_output_binding(
                    binding,
                    require_output_missing=True,
                )
        finally:
            module.cleanup_secure_output_root(binding)

    def test_home_descriptor_identity_substitution_is_rejected(self) -> None:
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        binding = module.create_secure_output_root(
            self.derived_data,
            "--derived-data-path",
        )
        try:
            self.assertTrue(
                hasattr(binding, "home_fd"),
                "private HOME must remain descriptor-bound",
            )
            replacement_home = self.directory / "replacement-home"
            replacement_home.mkdir(mode=0o700)
            replacement_fd = os.open(
                replacement_home,
                module.directory_open_flags(),
            )
            self.substitute_descriptor(binding, "home_fd", replacement_fd)
            with self.assertRaisesRegex(
                module.ValidationError,
                "home descriptor identity",
            ):
                module.require_secure_output_binding(
                    binding,
                    require_output_missing=True,
                )
        finally:
            module.cleanup_secure_output_root(binding)

    def test_temporary_descriptor_identity_substitution_is_rejected(self) -> None:
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        binding = module.create_secure_output_root(
            self.derived_data,
            "--derived-data-path",
        )
        try:
            self.assertTrue(
                hasattr(binding, "temporary_fd"),
                "private TMPDIR must remain descriptor-bound",
            )
            replacement_temporary = self.directory / "replacement-temporary"
            replacement_temporary.mkdir(mode=0o700)
            replacement_fd = os.open(
                replacement_temporary,
                module.directory_open_flags(),
            )
            self.substitute_descriptor(
                binding,
                "temporary_fd",
                replacement_fd,
            )
            with self.assertRaisesRegex(
                module.ValidationError,
                "temporary descriptor identity",
            ):
                module.require_secure_output_binding(
                    binding,
                    require_output_missing=True,
                )
        finally:
            module.cleanup_secure_output_root(binding)

    def test_cleanup_anchor_replacement_fails_without_touching_replacement(
        self,
    ) -> None:
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        binding = module.create_secure_output_root(
            self.derived_data,
            "--derived-data-path",
        )
        held_name = binding.anchor_name + "-held"
        os.fchmod(binding.anchor_fd, 0o700)
        os.rename(
            binding.anchor_name,
            held_name,
            src_dir_fd=binding.parent_fd,
            dst_dir_fd=binding.parent_fd,
        )
        os.fchmod(binding.anchor_fd, 0o500)
        replacement = binding.parent_path / binding.anchor_name
        replacement.mkdir(mode=0o700)
        marker = replacement / "do-not-touch.marker"
        marker.write_bytes(b"replacement-owned-marker")
        replacement_before = replacement.stat()
        marker_before = marker.stat()

        with self.assertRaisesRegex(
            module.CleanupError,
            "private anchor path changed before removal",
        ):
            module.cleanup_secure_output_root(binding)

        replacement_after = replacement.stat()
        marker_after = marker.stat()
        self.assertEqual(marker.read_bytes(), b"replacement-owned-marker")
        self.assertEqual(
            (replacement_after.st_dev, replacement_after.st_ino),
            (replacement_before.st_dev, replacement_before.st_ino),
        )
        self.assertEqual(
            (marker_after.st_dev, marker_after.st_ino, marker_after.st_size),
            (marker_before.st_dev, marker_before.st_ino, marker_before.st_size),
        )
        self.assertTrue((binding.parent_path / held_name).is_dir())

    def test_otherwise_successful_main_cleanup_failure_exits_four(self) -> None:
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        self.scenario_path.write_text(
            json.dumps(self.valid_scenario()),
            encoding="utf-8",
        )
        arguments = [
            str(RUNNER),
            "--xcodebuild-executable",
            str(self.fake_xcodebuild),
            "--xcresulttool-executable",
            str(self.fake_xcresulttool),
            "--package-path",
            str(self.package),
            "--scheme",
            "Fixture",
            "--destination",
            "platform=iOS Simulator,id=SIM-1",
            "--derived-data-path",
            str(self.derived_data),
            "--result-bundle-path",
            str(self.result_bundle),
            "--require-target",
            "FixtureTests",
        ]
        stdout = io.StringIO()
        stderr = io.StringIO()
        real_cleanup = module.cleanup_secure_output_root

        def cleanup_then_inject_failure(binding: object) -> None:
            real_cleanup(binding)
            if getattr(binding, "label") == "--result-bundle-path":
                raise module.CleanupError("injected terminal cleanup denial")

        with (
            mock.patch.object(sys, "argv", arguments),
            mock.patch.object(
                module,
                "cleanup_secure_output_root",
                side_effect=cleanup_then_inject_failure,
            ),
            contextlib.redirect_stdout(stdout),
            contextlib.redirect_stderr(stderr),
        ):
            exit_code = module.main()

        self.assertEqual(exit_code, 4)
        self.assertEqual(stdout.getvalue(), "")
        self.assertIn("cleanup failure", stderr.getvalue())
        self.assertIn("injected terminal cleanup denial", stderr.getvalue())
        self.assertNotIn("PASS", stdout.getvalue() + stderr.getvalue())
        self.assertFalse(self.derived_data.exists())
        self.assertFalse(self.result_bundle.exists())

    def test_xcodebuild_failure_is_distinct_and_cleans_created_roots(self) -> None:
        scenario = self.valid_scenario()
        scenario["xcodebuildReturncode"] = 9

        result = self.run_runner(scenario)

        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("xcodebuild failure", result.stderr)
        self.assertFalse(self.derived_data.exists())
        self.assertFalse(self.result_bundle.exists())
        self.assertEqual([call["tool"] for call in self.tool_log()], ["xcodebuild"])

    def test_timeout_terminates_process_group_and_cleans_no_residue(self) -> None:
        if not hasattr(os, "fork") or not hasattr(os, "killpg"):
            self.skipTest("process-group timeout test requires POSIX fork/killpg")
        scenario = self.valid_scenario()
        scenario["hangXcodebuild"] = True

        def force_cleanup() -> None:
            if not self.parent_pid_path.exists():
                return
            try:
                os.killpg(
                    int(self.parent_pid_path.read_text(encoding="ascii")),
                    signal.SIGKILL,
                )
            except (PermissionError, ProcessLookupError, ValueError):
                pass

        self.addCleanup(force_cleanup)
        result = self.run_runner(scenario, timeout_seconds=1.0)

        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("timed out", result.stderr)
        self.assertTrue(self.parent_pid_path.is_file())
        self.assertTrue(self.child_pid_path.is_file())
        child_pid = int(self.child_pid_path.read_text(encoding="ascii"))
        self.assertTrue(_wait_for_pid_exit(child_pid), "descendant survived timeout")
        self.assertFalse(self.derived_data.exists())
        self.assertFalse(self.result_bundle.exists())

    def test_run_process_rejects_zero_exit_with_live_group_descendant(
        self,
    ) -> None:
        if not hasattr(os, "fork") or not hasattr(os, "killpg"):
            self.skipTest("process-group residual test requires POSIX fork/killpg")
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        scenario = self.valid_scenario()
        scenario["zeroExitLeaderWithLiveDescendant"] = True
        self.scenario_path.write_text(json.dumps(scenario), encoding="utf-8")
        home = self.directory / "direct-home"
        temporary = self.directory / "direct-tmp"
        for directory in (home, temporary):
            directory.mkdir(mode=0o700)
            directory.chmod(0o700)
        environment = {
            "HOME": str(home),
            "LANG": "C",
            "LC_ALL": "C",
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
            "TMPDIR": str(temporary) + os.sep,
            "__CF_USER_TEXT_ENCODING": "0x0:0:0",
        }
        self.addCleanup(self.force_cleanup_orphan_group)

        try:
            with self.assertRaisesRegex(
                module.InvocationError,
                r"leader exited 0.*process-group descendants",
            ):
                module.run_process(
                    [str(self.fake_xcodebuild)],
                    cwd=self.package,
                    environment=environment,
                    timeout_seconds=4.0,
                    output_limit_bytes=1024 * 1024,
                )
        finally:
            if self.orphan_child_pid_path.exists():
                child_pid = int(self.orphan_child_pid_path.read_text(encoding="ascii"))
                if not _wait_for_pid_exit(child_pid):
                    self.force_cleanup_orphan_group()

        self.assertTrue(self.orphan_child_pid_path.is_file())
        child_pid = int(self.orphan_child_pid_path.read_text(encoding="ascii"))
        self.assertTrue(
            _wait_for_pid_exit(child_pid),
            "zero-exit leader descendant survived run_process",
        )
        self.assertFalse(self.orphan_marker_path.exists())

    def test_main_classifies_zero_exit_with_live_descendant_as_invocation_failure(
        self,
    ) -> None:
        if not hasattr(os, "fork") or not hasattr(os, "killpg"):
            self.skipTest("process-group residual test requires POSIX fork/killpg")
        scenario = self.valid_scenario()
        scenario["zeroExitLeaderWithLiveDescendant"] = True
        self.addCleanup(self.force_cleanup_orphan_group)

        result = self.run_runner(scenario, timeout_seconds=4.0)
        self.assertTrue(self.orphan_child_pid_path.is_file())
        child_pid = int(self.orphan_child_pid_path.read_text(encoding="ascii"))
        descendant_exited = _wait_for_pid_exit(child_pid)
        if not descendant_exited:
            self.force_cleanup_orphan_group()

        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("xcodebuild failure", result.stderr)
        self.assertRegex(
            result.stderr,
            r"leader exited 0.*process-group descendants",
        )
        self.assertNotIn("PASS", result.stdout + result.stderr)
        self.assertTrue(descendant_exited, "runner left a live group descendant")
        self.assertFalse(self.orphan_marker_path.exists())
        self.assertFalse(self.derived_data.exists())
        self.assertFalse(self.result_bundle.exists())

    def test_cleanup_error_is_a_failure(self) -> None:
        if not RUNNER.is_file():
            self.fail("run_nonempty_xcode_test.py is not implemented")
        module = importlib.import_module("scripts.run_nonempty_xcode_test")
        binding = module.create_secure_output_root(
            self.derived_data,
            "--derived-data-path",
        )

        with mock.patch.object(
            module,
            "_remove_directory_contents",
            side_effect=module.CleanupError("test-only cleanup denial"),
        ):
            with self.assertRaisesRegex(module.CleanupError, "cleanup denial"):
                module.cleanup_secure_output_root(binding)


if __name__ == "__main__":
    unittest.main()
