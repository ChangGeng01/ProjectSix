#!/usr/bin/env python3
"""Behavioral coverage for boundary-check command failures."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
from typing import Dict, Optional
import unittest


SCRIPT_DIR = Path(__file__).resolve().parent
REAL_RG = shutil.which("rg")
SCRIPT_NAMES = (
    "check_qinao_import_boundaries.sh",
    "check_sdk_import_boundaries.sh",
    "check_substrate_residual_markers.sh",
    "check_substrate_residuals.sh",
)


class BoundaryFixture:
    def __init__(self, test: unittest.TestCase) -> None:
        self.test = test
        self.temp = tempfile.TemporaryDirectory(prefix="boundary-tool-test-")
        self.root = Path(self.temp.name)
        (self.root / "scripts").mkdir()
        for name in SCRIPT_NAMES:
            shutil.copy2(SCRIPT_DIR / name, self.root / "scripts" / name)

        self.write("SampleHost/App.swift", "import Foundation\n")
        self.write("BehavioralAISubstrate/Sources/Core.swift", "import Foundation\n")
        self.write("BehavioralAISubstrate/README.md", "# Substrate\n")
        self.write("BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/CoreTests.swift", "import XCTest\n")
        self.write("QinaoRuntimeSDK/Sources/QinaoCore/Core.swift", "import Foundation\n")
        self.write("QinaoRuntimeSDK/Tests/QinaoCoreTests/CoreTests.swift", "import XCTest\n")
        self.make_command("swift", "exit \"${SWIFT_RC:-0}\"")
        self.make_script("check_sovereign_redaction.sh", "exit \"${REDACTION_RC:-0}\"")

    def cleanup(self) -> None:
        self.temp.cleanup()

    def write(self, relative: str, content: str) -> Path:
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def make_script(self, name: str, body: str) -> Path:
        path = self.write(f"scripts/{name}", f"#!/bin/bash\nset -eu\n{body}\n")
        path.chmod(0o755)
        return path

    def make_command(self, name: str, body: str) -> Path:
        commands = self.root / "commands"
        commands.mkdir(exist_ok=True)
        path = commands / name
        path.write_text(f"#!/bin/bash\nset -u\n{body}\n")
        path.chmod(0o755)
        return path

    def inject_rg(self) -> None:
        self.test.assertIsNotNone(REAL_RG, "rg-specific injected-failure fixture requires the real rg control")
        self.make_command(
            "rg",
            textwrap.dedent(
                """\
                joined="$*"
                if [[ -n "${FAIL_RG_TARGET:-}" && "$joined" == *"$FAIL_RG_TARGET"* ]] &&
                   [[ -z "${FAIL_RG_PATTERN:-}" || "$joined" == *"$FAIL_RG_PATTERN"* ]]; then
                  printf '%s\n' "${PARTIAL_OUTPUT-partial scanner output}"
                  echo "injected rg failure" >&2
                  exit 2
                fi
                exec "$REAL_RG" "$@"
                """
            ),
        )

    def inject_grep_filter_failure(self) -> None:
        self.make_command(
            "grep",
            textwrap.dedent(
                """\
                if [[ "${1:-}" == "-Ev" ]]; then
                  echo "partial filter output"
                  echo "injected grep filter failure" >&2
                  exit 2
                fi
                exec /usr/bin/grep "$@"
                """
            ),
        )

    def inject_grep_scanner_failure(self) -> None:
        self.make_command(
            "grep",
            textwrap.dedent(
                """\
                joined="$*"
                if [[ -n "${FAIL_GREP_TARGET:-}" && "$joined" == *"$FAIL_GREP_TARGET"* ]]; then
                  printf '%s\n' "${PARTIAL_OUTPUT-partial grep scanner output}"
                  echo "injected grep scanner failure" >&2
                  exit 2
                fi
                exec /usr/bin/grep "$@"
                """
            ),
        )

    def observe_mktemp(self, *, make_unwritable: bool = False) -> Path:
        receipt = self.root / "mktemp-receipt.txt"
        chmod = 'chmod 500 "$created"' if make_unwritable else ":"
        self.make_command(
            "mktemp",
            textwrap.dedent(
                f"""\
                created=$(/usr/bin/mktemp "$@") || exit $?
                {chmod}
                printf '%s\n' "$created" >> "$MKTEMP_RECEIPT"
                printf '%s\n' "$created"
                """
            ),
        )
        return receipt

    def block_filter_output(self, basename: str) -> Path:
        receipt = self.root / "mktemp-receipt.txt"
        self.make_command(
            "mktemp",
            textwrap.dedent(
                f"""\
                created=$(/usr/bin/mktemp "$@") || exit $?
                mkdir "$created/{basename}"
                printf '%s\n' "$created" >> "$MKTEMP_RECEIPT"
                printf '%s\n' "$created"
                """
            ),
        )
        return receipt

    def run(self, script: str, *, env: Optional[Dict[str, str]] = None, fallback: bool = False) -> subprocess.CompletedProcess[str]:
        merged = os.environ.copy()
        merged.pop("QINAO_SWIFT_BUILD_SYSTEM", None)
        base_path = "/usr/bin:/bin:/usr/sbin:/sbin" if fallback else os.environ["PATH"]
        merged["PATH"] = f"{self.root / 'commands'}:{base_path}"
        if REAL_RG:
            merged["REAL_RG"] = REAL_RG
        merged["TMPDIR"] = str(self.root / "tmp")
        (self.root / "tmp").mkdir(exist_ok=True)
        if env:
            merged.update(env)
        return subprocess.run(
            [str(self.root / "scripts" / script)],
            cwd=self.root,
            env=merged,
            text=True,
            capture_output=True,
            check=False,
        )


class BoundaryToolErrorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fx = BoundaryFixture(self)

    def tearDown(self) -> None:
        self.fx.cleanup()

    def assert_failed_without_pass(
        self,
        result: subprocess.CompletedProcess[str],
        diagnostic: Optional[str] = None,
    ) -> None:
        combined = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, combined)
        if diagnostic:
            self.assertIn(diagnostic, combined)
        for marker in (
            "Qinao import boundary check passed.",
            "BAS host import boundary check passed.",
            "BAS substrate residual scan passed.",
        ):
            self.assertNotIn(marker, combined)

    def test_signals_terminate_each_checker_and_cleanup(self) -> None:
        cases = (
            ("qinao", "check_qinao_import_boundaries.sh", "check_sdk_import_boundaries.sh"),
            ("sdk", "check_sdk_import_boundaries.sh", "check_substrate_residuals.sh"),
            ("residual", "check_substrate_residual_markers.sh", None),
        )
        for name, script, final_delegate in cases:
            with self.subTest(name=name):
                fx = BoundaryFixture(self)
                try:
                    receipt = fx.observe_mktemp()
                    if final_delegate:
                        fx.make_script(final_delegate, 'kill -TERM "$PPID"; exit 0')
                    else:
                        fx.test.assertIsNotNone(REAL_RG)
                        fx.make_command(
                            "rg",
                            textwrap.dedent(
                                """\
                                if [[ "$*" == *"BehavioralAISubstrate/Tests"* ]]; then
                                  kill -TERM "$PPID"
                                  exit 1
                                fi
                                exec "$REAL_RG" "$@"
                                """
                            ),
                        )
                    result = fx.run(script, env={"MKTEMP_RECEIPT": str(receipt)})
                    self.assert_failed_without_pass(result)
                    created = receipt.read_text().splitlines()
                    self.assertTrue(created)
                    self.assertTrue(all(not Path(path).exists() for path in created), created)
                finally:
                    fx.cleanup()

    def test_post_mktemp_output_open_failures_are_fatal(self) -> None:
        for script in ("check_sdk_import_boundaries.sh", "check_substrate_residual_markers.sh"):
            with self.subTest(script=script):
                fx = BoundaryFixture(self)
                try:
                    receipt = fx.observe_mktemp(make_unwritable=True)
                    result = fx.run(script, env={"MKTEMP_RECEIPT": str(receipt)})
                    self.assert_failed_without_pass(result, "cannot create scan output")
                    created = receipt.read_text().splitlines()
                    self.assertTrue(all(not Path(path).exists() for path in created), created)
                finally:
                    fx.cleanup()

    def test_filter_output_open_failures_are_fatal(self) -> None:
        cases = (
            (
                "check_sdk_import_boundaries.sh",
                "admin-import-violations.txt",
                "SampleHost/App.swift",
                "import BASAdmin\n",
            ),
            (
                "check_substrate_residual_markers.sh",
                "test-residuals.txt",
                "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitionCoreTests.swift",
                "let quickCapture = true\n",
            ),
        )
        for script, basename, fixture_path, content in cases:
            with self.subTest(script=script):
                fx = BoundaryFixture(self)
                try:
                    fx.write(fixture_path, content)
                    receipt = fx.block_filter_output(basename)
                    result = fx.run(script, env={"MKTEMP_RECEIPT": str(receipt)})
                    self.assert_failed_without_pass(result, "cannot create filter output")
                finally:
                    fx.cleanup()

    def test_real_searcher_controls(self) -> None:
        cases = (
            ("rg clean", False, None, 0, "residual scan passed"),
            ("grep fallback clean", True, None, 0, "residual scan passed"),
            ("violation", False, ("BehavioralAISubstrate/Sources/Core.swift", "let quickCapture = true\n"), 1, "residual scan failed"),
            ("allowed test marker", False, ("BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitionCoreTests.swift", "let quickCapture = true\n"), 0, "residual scan passed"),
        )
        for name, fallback, mutation, status, message in cases:
            with self.subTest(name=name):
                if mutation:
                    self.fx.write(*mutation)
                result = self.fx.run("check_substrate_residual_markers.sh", fallback=fallback)
                self.assertEqual(result.returncode, status, result.stdout + result.stderr)
                self.assertIn(message, (result.stdout + result.stderr).lower())
                if mutation:
                    self.fx.write(mutation[0], "import Foundation\n")

    def test_missing_input_and_forbidden_import_controls(self) -> None:
        shutil.rmtree(self.fx.root / "QinaoRuntimeSDK" / "Sources")
        missing = self.fx.run("check_qinao_import_boundaries.sh")
        self.assertEqual(missing.returncode, 1)
        self.assertIn("not found", missing.stderr)

        self.fx.write("SampleHost/App.swift", "import BASMemory\n")
        forbidden = self.fx.run("check_sdk_import_boundaries.sh", fallback=True)
        self.assertEqual(forbidden.returncode, 1, forbidden.stdout + forbidden.stderr)
        self.assertIn("forbidden", forbidden.stderr.lower())

    def test_residual_scan_propagates_source_readme_and_test_errors(self) -> None:
        self.fx.inject_rg()
        for target in ("BehavioralAISubstrate/Sources", "BehavioralAISubstrate/README.md", "BehavioralAISubstrate/Tests"):
            with self.subTest(target=target):
                result = self.fx.run("check_substrate_residual_markers.sh", env={"FAIL_RG_TARGET": target})
                self.assert_failed_without_pass(result, "injected rg failure")

    def test_residual_test_filter_propagates_error_after_partial_output(self) -> None:
        self.fx.write(
            "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/BASCognitionCoreTests.swift",
            "let quickCapture = true\n",
        )
        self.fx.inject_grep_filter_failure()
        result = self.fx.run("check_substrate_residual_markers.sh")
        self.assert_failed_without_pass(result, "filter errored")
        self.assertIn("partial filter output", result.stdout + result.stderr)

    def test_sdk_admin_filter_propagates_error_after_partial_output(self) -> None:
        self.fx.write("SampleHost/App.swift", "import BASAdmin\n")
        self.fx.inject_grep_filter_failure()
        result = self.fx.run("check_sdk_import_boundaries.sh")
        self.assert_failed_without_pass(result, "filter errored")
        self.assertIn("partial filter output", result.stdout + result.stderr)

    def test_qinao_scan_propagates_loop_and_assignment_errors(self) -> None:
        self.fx.inject_rg()
        cases = (
            ("loop", "^import [A-Za-z]", "fixture.swift:1:import Foundation"),
            ("assignment", "Before|SampleHost", ""),
        )
        for name, pattern, partial_output in cases:
            with self.subTest(name=name):
                result = self.fx.run(
                    "check_qinao_import_boundaries.sh",
                    env={
                        "FAIL_RG_TARGET": "QinaoRuntimeSDK/Sources",
                        "FAIL_RG_PATTERN": pattern,
                        "PARTIAL_OUTPUT": partial_output,
                    },
                )
                self.assert_failed_without_pass(result, "scanner errored")

    def test_grep_fallback_scanner_errors_are_fatal(self) -> None:
        cases = (
            ("qinao", "check_qinao_import_boundaries.sh", "QinaoRuntimeSDK/Sources", "fixture.swift:1:import Foundation"),
            ("sdk", "check_sdk_import_boundaries.sh", "SampleHost", ""),
            ("residual", "check_substrate_residual_markers.sh", "BehavioralAISubstrate/Sources", ""),
        )
        for name, script, target, partial in cases:
            with self.subTest(name=name):
                fx = BoundaryFixture(self)
                try:
                    fx.inject_grep_scanner_failure()
                    result = fx.run(
                        script,
                        fallback=True,
                        env={"FAIL_GREP_TARGET": target, "PARTIAL_OUTPUT": partial},
                    )
                    self.assert_failed_without_pass(result, "injected grep scanner failure")
                finally:
                    fx.cleanup()

    def test_qinao_optional_tests_and_partial_test_scan_failure(self) -> None:
        shutil.rmtree(self.fx.root / "QinaoRuntimeSDK" / "Tests")
        self.fx.make_script("check_sdk_import_boundaries.sh", "exit 0")
        optional_absent = self.fx.run("check_qinao_import_boundaries.sh")
        self.assertEqual(optional_absent.returncode, 0, optional_absent.stdout + optional_absent.stderr)

        self.fx.write("QinaoRuntimeSDK/Tests/QinaoCoreTests/CoreTests.swift", "import XCTest\n")
        self.fx.inject_rg()
        failed = self.fx.run(
            "check_qinao_import_boundaries.sh",
            env={
                "FAIL_RG_TARGET": "QinaoRuntimeSDK/Tests",
                "FAIL_RG_PATTERN": "^(@testable )?import",
                "PARTIAL_OUTPUT": "fixture.swift:1:import XCTest",
            },
        )
        self.assert_failed_without_pass(failed, "scanner errored")

    def test_qinao_build_redaction_and_delegated_failures_prevent_success(self) -> None:
        cases = (
            ("build", {"SWIFT_RC": "7"}),
            ("redaction", {"REDACTION_RC": "8"}),
            ("delegated", {"SDK_RC": "9"}),
        )
        self.fx.make_script("check_sdk_import_boundaries.sh", "exit \"${SDK_RC:-0}\"")
        for name, env in cases:
            with self.subTest(name=name):
                result = self.fx.run("check_qinao_import_boundaries.sh", env=env)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertNotIn("check passed", (result.stdout + result.stderr).lower())

    def test_qinao_backend_choice_reaches_build_and_symbol_emission_in_order(self) -> None:
        shutil.copy2(
            SCRIPT_DIR / "check_sovereign_redaction.sh",
            self.fx.root / "scripts/check_sovereign_redaction.sh",
        )
        swift_calls = self.fx.root / "swift-calls.txt"
        self.fx.make_command(
            "swift",
            textwrap.dedent(
                """\
                printf '%s\n' "$*" >> "$SWIFT_CALLS"
                case "$*" in
                  build|"build --build-system native")
                    [[ "${SWIFT_FAIL_ON:-}" != build ]] || exit 77
                    ;;
                  "package dump-symbol-graph"|"package --build-system native dump-symbol-graph")
                    [[ "${SWIFT_FAIL_ON:-}" != package ]] || exit 78
                    graph=.build/fixture/symbolgraph/QinaoCore.symbols.json
                    mkdir -p "${graph%/*}"
                    printf '%s\n' '{"module":{"name":"QinaoCore"},"symbols":[]}' > "$graph"
                    ;;
                  *) exit 64 ;;
                esac
                """
            ),
        )
        self.fx.make_script("check_sdk_import_boundaries.sh", "exit 0")

        for choice, expected in (
            (None, ["build", "package dump-symbol-graph"]),
            ("default", ["build", "package dump-symbol-graph"]),
            (
                "native",
                [
                    "build --build-system native",
                    "package --build-system native dump-symbol-graph",
                ],
            ),
        ):
            with self.subTest(choice=choice):
                swift_calls.unlink(missing_ok=True)
                env = {"SWIFT_CALLS": str(swift_calls)}
                if choice is not None:
                    env["QINAO_SWIFT_BUILD_SYSTEM"] = choice
                result = self.fx.run("check_qinao_import_boundaries.sh", env=env)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(swift_calls.read_text().splitlines(), expected)

    def test_invalid_qinao_backend_is_rejected_before_build_or_emission(self) -> None:
        swift_calls = self.fx.root / "swift-calls.txt"
        self.fx.make_command("swift", 'printf "%s\\n" "$*" >> "$SWIFT_CALLS"')
        for choice in ("", "xcode", "native extra"):
            with self.subTest(choice=choice):
                swift_calls.unlink(missing_ok=True)
                result = self.fx.run(
                    "check_qinao_import_boundaries.sh",
                    env={
                        "QINAO_SWIFT_BUILD_SYSTEM": choice,
                        "SWIFT_CALLS": str(swift_calls),
                    },
                )
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertFalse(swift_calls.exists())
                self.assertIn("QINAO_SWIFT_BUILD_SYSTEM", result.stderr)

    def test_native_backend_build_and_emission_failures_remain_fatal(self) -> None:
        shutil.copy2(
            SCRIPT_DIR / "check_sovereign_redaction.sh",
            self.fx.root / "scripts/check_sovereign_redaction.sh",
        )
        swift_calls = self.fx.root / "swift-calls.txt"
        self.fx.make_command(
            "swift",
            textwrap.dedent(
                """\
                printf '%s\n' "$*" >> "$SWIFT_CALLS"
                [[ "$*" != "build --build-system native" || "$SWIFT_FAIL_ON" != build ]] || exit 77
                [[ "$*" != "package --build-system native dump-symbol-graph" || "$SWIFT_FAIL_ON" != package ]] || exit 78
                if [[ "$*" == "package --build-system native dump-symbol-graph" ]]; then
                  graph=.build/fixture/symbolgraph/QinaoCore.symbols.json
                  mkdir -p "${graph%/*}"
                  printf '%s\n' '{"module":{"name":"QinaoCore"},"symbols":[]}' > "$graph"
                fi
                """
            ),
        )
        self.fx.make_script("check_sdk_import_boundaries.sh", "exit 0")
        for failure in ("build", "package"):
            with self.subTest(failure=failure):
                swift_calls.unlink(missing_ok=True)
                result = self.fx.run(
                    "check_qinao_import_boundaries.sh",
                    env={
                        "QINAO_SWIFT_BUILD_SYSTEM": "native",
                        "SWIFT_CALLS": str(swift_calls),
                        "SWIFT_FAIL_ON": failure,
                    },
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("check passed", (result.stdout + result.stderr).lower())
                calls = swift_calls.read_text().splitlines()
                expected = [
                    "build --build-system native",
                    "package --build-system native dump-symbol-graph",
                ]
                self.assertEqual(calls, expected)

    def test_output_creation_failure_is_fatal(self) -> None:
        bad_tmp = self.fx.root / "does-not-exist" / "tmp"
        env = os.environ.copy()
        env["PATH"] = f"{self.fx.root / 'commands'}:{os.environ['PATH']}"
        env["TMPDIR"] = str(bad_tmp)
        result = subprocess.run(
            [str(self.fx.root / "scripts" / "check_substrate_residual_markers.sh")],
            cwd=self.fx.root,
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
        self.assert_failed_without_pass(result, "mktemp")

    def test_concurrent_runs_own_and_clean_their_temporary_outputs(self) -> None:
        receipt = self.fx.observe_mktemp()
        env = os.environ.copy()
        env["PATH"] = f"{self.fx.root / 'commands'}:{os.environ['PATH']}"
        env["TMPDIR"] = str(self.fx.root / "tmp")
        env["MKTEMP_RECEIPT"] = str(receipt)
        (self.fx.root / "tmp").mkdir(exist_ok=True)
        command = [str(self.fx.root / "scripts" / "check_substrate_residual_markers.sh")]
        runs = [subprocess.Popen(command, cwd=self.fx.root, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE) for _ in range(2)]
        outcomes = [run.communicate(timeout=10) + (run.returncode,) for run in runs]
        self.assertEqual([item[2] for item in outcomes], [0, 0], outcomes)

        self.fx.inject_rg()
        error_env = env | {
            "FAIL_RG_TARGET": "BehavioralAISubstrate/Sources",
            "REAL_RG": REAL_RG or "",
        }
        failed = subprocess.run(command, cwd=self.fx.root, env=error_env, text=True, capture_output=True, check=False)
        self.assertNotEqual(failed.returncode, 0, failed.stdout + failed.stderr)

        created = receipt.read_text().splitlines()
        self.assertEqual(len(created), 3, created)
        self.assertEqual(len(set(created)), 3, created)
        self.assertTrue(all(not Path(path).exists() for path in created), created)
        self.assertEqual(list((self.fx.root / "tmp").iterdir()), [])


if __name__ == "__main__":
    unittest.main()
