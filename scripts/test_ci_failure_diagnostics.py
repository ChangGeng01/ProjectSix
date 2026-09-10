from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.test_test_workflow_owner_ledger import ORDINARY_WORKFLOW, _parse_yaml


ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "scripts/run_ci_swift_tests.sh"
GRAPH_CHECK = ROOT / "scripts/check_sovereign_redaction.sh"
UPLOAD_ACTION = "actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02"


class DiagnosticsFixture:
    def __init__(self) -> None:
        self.temp = tempfile.TemporaryDirectory(prefix="ci-failure-diagnostics-")
        self.root = Path(self.temp.name) / "Repository With Spaces"
        self.scripts = self.root / "scripts"
        self.commands = self.root / "commands"
        self.runner_temp = self.root / "Runner Temp"
        self.home = self.root / "Fake Home"
        self.reports = self.home / "Library/Logs/DiagnosticReports"
        self.scripts.mkdir(parents=True)
        self.commands.mkdir()
        self.runner_temp.mkdir()
        self.reports.mkdir(parents=True)
        (self.root / "BehavioralAISubstrate").mkdir()
        (self.root / "QinaoRuntimeSDK").mkdir()
        if RUNNER.exists():
            shutil.copy2(RUNNER, self.scripts / RUNNER.name)
        shutil.copy2(GRAPH_CHECK, self.scripts / GRAPH_CHECK.name)
        self.swift_log = self.root / "swift-calls.txt"
        self.cwd_log = self.root / "swift-cwds.txt"
        self.sleep_log = self.root / "sleep-calls.txt"
        self.scanner_log = self.root / "scanner-calls.txt"
        self._make_command("swift", r'''
printf '%s\n' "$*" >> "$SWIFT_CALLS"
pwd >> "$SWIFT_CWDS"
case "$1" in
  test)
    count=1
    [[ ! -f "$TEST_ATTEMPT" ]] || count=$(( $(< "$TEST_ATTEMPT") + 1 ))
    printf '%s\n' "$count" > "$TEST_ATTEMPT"
    if [[ "$count" == 1 ]]; then
      printf 'primary output\n'
      case "${REPORT_MODE:-none}" in
        matching-new)
          printf 'matching report\n' > "$REPORTS/xctest-fixture.ips"
          /usr/bin/touch -t 203001010000 "$REPORTS/xctest-fixture.ips"
          ;;
        matching-old)
          printf 'old matching report\n' > "$REPORTS/QinaoRuntimeSDKPackageTests-old.crash"
          /usr/bin/touch -t 202001010000 "$REPORTS/QinaoRuntimeSDKPackageTests-old.crash"
          ;;
        unrelated-new)
          printf 'unrelated report\n' > "$REPORTS/OtherProcess.ips"
          /usr/bin/touch -t 203001010000 "$REPORTS/OtherProcess.ips"
          ;;
      esac
      diag_path=
      for candidate in "$RUNNER_TEMP"/bas-xctest-diagnostics.* \
                       "$RUNNER_TEMP"/qinao-xctest-diagnostics.*; do
        [[ -d "$candidate" ]] && diag_path="$candidate"
      done
      case "${PRIMARY_INJECT:-none}" in
        exits-directory)
          /bin/mkdir "$diag_path/exits.txt"
          ;;
        report-dir-file)
          printf 'blocked\n' > "$diag_path/crash-reports"
          ;;
        no-report-directory)
          /bin/mkdir -p "$diag_path/crash-reports/no-report.txt"
          ;;
        selected-paths-directory)
          /bin/mkdir -p "$diag_path/crash-reports/selected-paths.txt"
          ;;
      esac
      exit "${PRIMARY_RC:-0}"
    fi
    printf 'probe output\n'
    exit "${PROBE_RC:-0}"
    ;;
  package)
    count=1
    [[ ! -f "$GRAPH_ATTEMPT" ]] || count=$(( $(< "$GRAPH_ATTEMPT") + 1 ))
    printf '%s\n' "$count" > "$GRAPH_ATTEMPT"
    /bin/mkdir -p .build/fixture/debug/Modules
    if [[ "$count" == 1 ]]; then
      if [[ "${FIRST_EMIT_MODULE:-1}" == 1 ]]; then
        printf 'original module' > .build/fixture/debug/Modules/QinaoRuntimeSDKPackageTests.swiftmodule
      fi
      if [[ "${FIRST_EMIT_GRAPH:-1}" == 1 ]]; then
        /bin/mkdir -p .build/fixture/symbolgraph
        printf 'original graph' > .build/fixture/symbolgraph/QinaoRuntimeSDK.symbols.json
      fi
      printf 'first dump failed\n'
      exit "${GRAPH_RC:-0}"
    fi
    if [[ "${RETRY_EMIT_MODULE:-1}" == 1 ]]; then
      printf 'retry module' > .build/fixture/debug/Modules/QinaoRuntimeSDKPackageTests.swiftmodule
    fi
    if [[ "${RETRY_EMIT_GRAPH:-1}" == 1 ]]; then
      /bin/mkdir -p .build/fixture/symbolgraph
      printf 'retry graph' > .build/fixture/symbolgraph/QinaoRuntimeSDK.symbols.json
    fi
    printf 'retry dump output\n'
    exit "${RETRY_RC:-0}"
    ;;
  build)
    printf 'build output\n'
    exit "${BUILD_RC:-0}"
    ;;
  *) exit 64 ;;
esac
''')
        self._make_command("sleep", r'''
printf '%s\n' "$*" >> "$SLEEP_CALLS"
exit "${SLEEP_RC:-0}"
''')
        self._make_command("tee", r'''
/usr/bin/tee "$@"
real_rc=$?
[[ "$real_rc" == 0 ]] || exit "$real_rc"
exit "${TEE_RC:-0}"
''')
        self._make_command("cp", r'''
[[ "${CP_RC:-0}" == 0 ]] || exit "$CP_RC"
/bin/cp "$@"
''')
        self._make_command("mv", r'''
[[ "${MV_RC:-0}" == 0 ]] || exit "$MV_RC"
/bin/mv "$@"
''')
        self._make_command("find", r'''
[[ "${FIND_RC:-0}" == 0 ]] || exit "$FIND_RC"
/usr/bin/find "$@"
''')
        self._make_command("mkdir", r'''
for argument in "$@"; do
  if [[ "$argument" == *after-test-products* && "${AFTER_STAGE_RC:-0}" != 0 ]]; then
    exit "$AFTER_STAGE_RC"
  fi
done
/bin/mkdir "$@"
''')
        self._make_command("python3", r'''
printf 'scanner\n' >> "$SCANNER_CALLS"
cat >/dev/null
exit "${SCANNER_RC:-0}"
''')

    def cleanup(self) -> None:
        self.temp.cleanup()

    def _make_command(self, name: str, body: str) -> None:
        path = self.commands / name
        path.write_text(f"#!/bin/bash\nset -u\n{body.strip()}\n", encoding="utf-8")
        path.chmod(0o700)

    def environment(self, **overrides: str) -> dict[str, str]:
        env = {
            "PATH": f"{self.commands}:/usr/bin:/bin",
            "RUNNER_TEMP": str(self.runner_temp),
            "HOME": str(self.home),
            "SWIFT_CALLS": str(self.swift_log),
            "SWIFT_CWDS": str(self.cwd_log),
            "SLEEP_CALLS": str(self.sleep_log),
            "SCANNER_CALLS": str(self.scanner_log),
            "TEST_ATTEMPT": str(self.root / "test-attempt"),
            "GRAPH_ATTEMPT": str(self.root / "graph-attempt"),
            "REPORTS": str(self.reports),
            "PRIMARY_RC": "0",
            "PROBE_RC": "0",
            "GRAPH_RC": "0",
            "BUILD_RC": "0",
            "RETRY_RC": "0",
            "FIRST_EMIT_MODULE": "1",
            "FIRST_EMIT_GRAPH": "1",
            "RETRY_EMIT_MODULE": "1",
            "RETRY_EMIT_GRAPH": "1",
            "TEE_RC": "0",
            "CP_RC": "0",
            "MV_RC": "0",
            "FIND_RC": "0",
            "SLEEP_RC": "0",
            "SCANNER_RC": "0",
            "REPORT_MODE": "none",
            "PRIMARY_INJECT": "none",
            "AFTER_STAGE_RC": "0",
        }
        env.update(overrides)
        return env

    def run_tests(self, mode: str, **overrides: int | str) -> subprocess.CompletedProcess[str]:
        cwd = self.root if mode == "bas" else self.root / "QinaoRuntimeSDK"
        script = self.scripts / "run_ci_swift_tests.sh"
        rendered = {key.upper(): str(value) for key, value in overrides.items()}
        return subprocess.run(
            ["/bin/bash", str(script), mode], cwd=cwd,
            env=self.environment(**rendered), capture_output=True, text=True,
            check=False, timeout=10,
        )

    def run_runner_args(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/bash", str(self.scripts / "run_ci_swift_tests.sh"), *arguments],
            cwd=self.root, env=self.environment(), capture_output=True, text=True,
            check=False, timeout=10,
        )

    def run_graph(self, *, ci: bool, **overrides: int | str) -> subprocess.CompletedProcess[str]:
        rendered = {key.upper(): str(value) for key, value in overrides.items()}
        if ci:
            rendered["QINAO_CI_DIAGNOSTICS"] = "1"
        return subprocess.run(
            ["/bin/bash", str(self.scripts / "check_sovereign_redaction.sh")],
            cwd=self.root,
            env=self.environment(QINAO_SWIFT_BUILD_SYSTEM="native", **rendered),
            capture_output=True, text=True, check=False, timeout=10,
        )

    def swift_calls(self) -> list[str]:
        return self.swift_log.read_text().splitlines() if self.swift_log.exists() else []

    def swift_cwds(self) -> list[str]:
        return self.cwd_log.read_text().splitlines() if self.cwd_log.exists() else []

    def sleep_calls(self) -> list[str]:
        return self.sleep_log.read_text().splitlines() if self.sleep_log.exists() else []

    def scanner_calls(self) -> list[str]:
        return self.scanner_log.read_text().splitlines() if self.scanner_log.exists() else []

    def diagnostics(self, pattern: str) -> list[Path]:
        return sorted(path for path in self.runner_temp.glob(pattern) if path.is_dir())

    @staticmethod
    def graph_bytes(diag: Path, phase: str) -> bytes:
        matches = list((diag / phase / "graphs").rglob("QinaoRuntimeSDK.symbols.json"))
        if len(matches) != 1:
            raise AssertionError(f"expected one retained graph in {phase}, got {matches}")
        return matches[0].read_bytes()

    @staticmethod
    def module_bytes(diag: Path, phase: str) -> bytes:
        matches = list((diag / phase / "modules").rglob("QinaoRuntimeSDKPackageTests.swiftmodule"))
        if len(matches) != 1:
            raise AssertionError(f"expected one retained module in {phase}, got {matches}")
        return matches[0].read_bytes()


class CIFailureDiagnosticsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fx = DiagnosticsFixture()

    def tearDown(self) -> None:
        self.fx.cleanup()

    def test_runner_rejects_every_shape_except_one_known_mode_before_swift(self) -> None:
        for arguments in ((), ("unknown",), ("bas", "extra")):
            with self.subTest(arguments=arguments):
                result = self.fx.run_runner_args(*arguments)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(self.fx.swift_calls(), [])

    def test_both_modes_succeed_with_one_exact_primary_command_and_no_probe(self) -> None:
        cases = {
            "bas": "test --build-system native --package-path BehavioralAISubstrate",
            "qinao": "test --build-system native",
        }
        for mode, expected in cases.items():
            with self.subTest(mode=mode):
                fx = DiagnosticsFixture()
                try:
                    result = fx.run_tests(mode, primary_rc=0)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(fx.swift_calls(), [expected])
                    expected_cwd = fx.root if mode == "bas" else fx.root / "QinaoRuntimeSDK"
                    self.assertEqual(fx.swift_cwds(), [str(expected_cwd)])
                    self.assertEqual(len(fx.diagnostics(f"{mode}-xctest-diagnostics.*")), 1)
                finally:
                    fx.cleanup()

    def test_probe_success_cannot_hide_primary_failure(self) -> None:
        result = self.fx.run_tests("bas", primary_rc=139, probe_rc=0)
        self.assertEqual(result.returncode, 139, result.stderr)
        self.assertEqual(self.fx.swift_calls(), [
            "test --build-system native --package-path BehavioralAISubstrate",
            "test --build-system native --package-path BehavioralAISubstrate --skip-build --disable-swift-testing",
        ])
        diag = self.fx.diagnostics("bas-xctest-diagnostics.*")[0]
        self.assertEqual((diag / "primary.log").read_text(), "primary output\n")
        self.assertEqual((diag / "full-xctest-retained-products.log").read_text(), "probe output\n")

    def test_primary_and_probe_failures_are_separate_and_primary_wins(self) -> None:
        result = self.fx.run_tests("qinao", primary_rc=23, probe_rc=24)
        self.assertEqual(result.returncode, 23, result.stderr)
        diag = self.fx.diagnostics("qinao-xctest-diagnostics.*")[0]
        exits = (diag / "exits.txt").read_text()
        self.assertIn("primary=23\n", exits)
        self.assertIn("probe=24\n", exits)

    def test_two_consecutive_failures_allocate_unique_diagnostic_directories(self) -> None:
        first = self.fx.run_tests("bas", primary_rc=7)
        (self.fx.root / "test-attempt").unlink()
        second = self.fx.run_tests("bas", primary_rc=8)
        self.assertEqual((first.returncode, second.returncode), (7, 8))
        self.assertEqual(len(self.fx.diagnostics("bas-xctest-diagnostics.*")), 2)

    def test_capture_and_report_copy_failures_never_replace_primary_failure(self) -> None:
        tee_result = self.fx.run_tests("bas", primary_rc=31, tee_rc=32)
        self.assertEqual(tee_result.returncode, 31, tee_result.stderr)
        tee_diag = self.fx.diagnostics("bas-xctest-diagnostics.*")[0]
        self.assertIn("primary_capture=32\n", (tee_diag / "exits.txt").read_text())

        fx = DiagnosticsFixture()
        try:
            copy_result = fx.run_tests("bas", primary_rc=33, report_mode="matching-new", cp_rc=34)
            self.assertEqual(copy_result.returncode, 33, copy_result.stderr)
            diag = fx.diagnostics("bas-xctest-diagnostics.*")[0]
            self.assertIn("copy", (diag / "crash-reports/collection-errors.txt").read_text().lower())
        finally:
            fx.cleanup()

    def test_capture_failure_cannot_turn_success_green(self) -> None:
        result = self.fx.run_tests("bas", primary_rc=0, tee_rc=41)
        self.assertEqual(result.returncode, 41, result.stderr)
        self.assertEqual(len(self.fx.swift_calls()), 1)

    def test_initial_exit_metadata_failure_preserves_primary_status_and_output(self) -> None:
        result = self.fx.run_tests("bas", primary_rc=61, primary_inject="exits-directory")
        self.assertEqual(result.returncode, 61, result.stderr)
        diag = self.fx.diagnostics("bas-xctest-diagnostics.*")[0]
        self.assertEqual((diag / "primary.log").read_text(), "primary output\n")
        self.assertIn("exits.txt", result.stderr)
        self.assertEqual(self.fx.swift_calls(), [
            "test --build-system native --package-path BehavioralAISubstrate",
            "test --build-system native --package-path BehavioralAISubstrate --skip-build --disable-swift-testing",
        ])

    def test_report_directory_setup_failure_preserves_primary_status(self) -> None:
        result = self.fx.run_tests("qinao", primary_rc=62, primary_inject="report-dir-file")
        self.assertEqual(result.returncode, 62, result.stderr)
        diag = self.fx.diagnostics("qinao-xctest-diagnostics.*")[0]
        self.assertEqual((diag / "primary.log").read_text(), "primary output\n")
        self.assertIn("crash-report directory", result.stderr)
        self.assertEqual(len(self.fx.swift_calls()), 2)

    def test_later_report_metadata_failures_preserve_primary_status(self) -> None:
        cases = (
            ("no-report-directory", "none", "no-report.txt"),
            ("selected-paths-directory", "matching-new", "selected-paths.txt"),
        )
        for injection, report_mode, expected_error in cases:
            with self.subTest(injection=injection):
                fx = DiagnosticsFixture()
                try:
                    result = fx.run_tests(
                        "bas", primary_rc=63, primary_inject=injection,
                        report_mode=report_mode,
                    )
                    self.assertEqual(result.returncode, 63, result.stderr)
                    diag = fx.diagnostics("bas-xctest-diagnostics.*")[0]
                    self.assertEqual((diag / "primary.log").read_text(), "primary output\n")
                    self.assertIn(expected_error, result.stderr)
                    self.assertEqual(len(fx.swift_calls()), 2)
                finally:
                    fx.cleanup()

    def test_no_new_report_is_explicit_and_polling_is_bounded(self) -> None:
        result = self.fx.run_tests("qinao", primary_rc=42)
        self.assertEqual(result.returncode, 42, result.stderr)
        diag = self.fx.diagnostics("qinao-xctest-diagnostics.*")[0]
        self.assertTrue((diag / "crash-reports/no-report.txt").is_file())
        self.assertLessEqual(len(self.fx.sleep_calls()), 5)
        self.assertTrue(all(call == "2" for call in self.fx.sleep_calls()))

    def test_report_poll_failure_is_recorded_without_replacing_primary_failure(self) -> None:
        result = self.fx.run_tests("qinao", primary_rc=42, find_rc=52)
        self.assertEqual(result.returncode, 42, result.stderr)
        diag = self.fx.diagnostics("qinao-xctest-diagnostics.*")[0]
        errors = (diag / "crash-reports/collection-errors.txt").read_text()
        self.assertIn("polling failed with exit 52", errors)
        self.assertFalse((diag / "crash-reports/no-report.txt").exists())

    def test_only_matching_new_reports_are_copied_and_selected_paths_are_retained(self) -> None:
        old = self.fx.reports / "xctest-old.ips"
        old.write_text("old report\n")
        os.utime(old, (1_577_836_800, 1_577_836_800))
        unrelated = self.fx.reports / "OtherProcess.crash"
        unrelated.write_text("unrelated\n")
        os.utime(unrelated, (1_893_456_000, 1_893_456_000))
        result = self.fx.run_tests("bas", primary_rc=43, report_mode="matching-new")
        self.assertEqual(result.returncode, 43, result.stderr)
        diag = self.fx.diagnostics("bas-xctest-diagnostics.*")[0]
        copied = sorted(path for path in (diag / "crash-reports").iterdir()
                        if path.suffix in {".ips", ".crash"})
        self.assertEqual([path.read_text() for path in copied], ["matching report\n"])
        selected = (diag / "crash-reports/selected-paths.txt").read_text()
        self.assertIn("xctest-fixture.ips", selected)
        self.assertNotIn("xctest-old.ips", selected)
        self.assertNotIn("OtherProcess.crash", selected)

    def test_local_graph_failure_does_not_add_diagnostics_or_retry(self) -> None:
        result = self.fx.run_graph(ci=False, graph_rc=44)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.fx.swift_calls(), [
            "package --build-system native dump-symbol-graph",
        ])
        self.assertEqual(self.fx.diagnostics("qinao-symbolgraph-diagnostics.*"), [])
        self.assertEqual(self.fx.scanner_calls(), [])

    def test_local_and_ci_graph_success_run_the_unchanged_scanner(self) -> None:
        for ci in (False, True):
            with self.subTest(ci=ci):
                fx = DiagnosticsFixture()
                try:
                    result = fx.run_graph(ci=ci, graph_rc=0)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(fx.swift_calls(), [
                        "package --build-system native dump-symbol-graph",
                    ])
                    self.assertEqual(fx.scanner_calls(), ["scanner"])
                finally:
                    fx.cleanup()

    def test_graph_retry_never_enters_scanner_or_loses_first_bytes(self) -> None:
        result = self.fx.run_graph(ci=True, graph_rc=42, build_rc=0, retry_rc=0)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.fx.scanner_calls(), [])
        self.assertEqual(self.fx.swift_calls(), [
            "package --build-system native dump-symbol-graph",
            "build --build-system native --build-tests --verbose",
            "package --build-system native --verbose dump-symbol-graph",
        ])
        diag = self.fx.diagnostics("qinao-symbolgraph-diagnostics.*")[0]
        self.assertEqual((diag / "first-pass/dump.log").read_text(), "first dump failed\n")
        self.assertEqual(self.fx.graph_bytes(diag, "first-pass"), b"original graph")
        self.assertEqual(self.fx.graph_bytes(diag, "after-test-products"), b"retry graph")
        self.assertEqual(self.fx.module_bytes(diag, "first-pass"), b"original module")
        self.assertEqual(self.fx.module_bytes(diag, "after-test-products"), b"retry module")

    def test_empty_graph_diagnostic_collections_preserve_failure_and_complete_after_phase(self) -> None:
        cases = (
            dict(first_emit_module=0, first_emit_graph=0,
                 retry_emit_module=0, retry_emit_graph=0),
            dict(first_emit_module=0, first_emit_graph=1,
                 retry_emit_module=0, retry_emit_graph=0),
            dict(first_emit_module=1, first_emit_graph=0,
                 retry_emit_module=1, retry_emit_graph=1),
        )
        expected_calls = [
            "package --build-system native dump-symbol-graph",
            "build --build-system native --build-tests --verbose",
            "package --build-system native --verbose dump-symbol-graph",
        ]
        for case in cases:
            with self.subTest(case=case):
                fx = DiagnosticsFixture()
                try:
                    result = fx.run_graph(
                        ci=True, graph_rc=71, build_rc=0, retry_rc=0, **case,
                    )
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertNotIn("unbound variable", result.stderr)
                    self.assertEqual(fx.scanner_calls(), [])
                    self.assertEqual(fx.swift_calls(), expected_calls)
                    diag = fx.diagnostics("qinao-symbolgraph-diagnostics.*")[0]
                    self.assertEqual(
                        (diag / "first-pass/dump.log").read_text(),
                        "first dump failed\n",
                    )
                    self.assertEqual((diag / "exits.txt").read_text().splitlines(), [
                        "first_dump=71",
                        "preservation=0",
                        "build_tests=0",
                        "retry_dump=0",
                        "after_preservation=0",
                    ])
                    phase_flags = (
                        ("first-pass", "modules", case["first_emit_module"]),
                        ("first-pass", "graphs", case["first_emit_graph"]),
                        ("after-test-products", "modules", case["retry_emit_module"]),
                        ("after-test-products", "graphs", case["retry_emit_graph"]),
                    )
                    for phase, collection, emitted in phase_flags:
                        listing = diag / phase / f"{collection}.list"
                        self.assertTrue(listing.is_file(), listing)
                        if not emitted:
                            self.assertEqual(listing.read_bytes(), b"")
                    if case["first_emit_module"]:
                        self.assertEqual(fx.module_bytes(diag, "first-pass"), b"original module")
                    if case["first_emit_graph"]:
                        self.assertEqual(fx.graph_bytes(diag, "first-pass"), b"original graph")
                    if case["retry_emit_module"]:
                        self.assertEqual(fx.module_bytes(diag, "after-test-products"), b"retry module")
                    if case["retry_emit_graph"]:
                        self.assertEqual(fx.graph_bytes(diag, "after-test-products"), b"retry graph")
                finally:
                    fx.cleanup()

    def test_graph_build_and_retry_failures_are_recorded_separately(self) -> None:
        result = self.fx.run_graph(ci=True, graph_rc=45, build_rc=46, retry_rc=47)
        self.assertEqual(result.returncode, 1, result.stderr)
        diag = self.fx.diagnostics("qinao-symbolgraph-diagnostics.*")[0]
        exits = (diag / "exits.txt").read_text()
        self.assertIn("first_dump=45\n", exits)
        self.assertIn("build_tests=46\n", exits)
        self.assertIn("retry_dump=47\n", exits)
        self.assertEqual((diag / "after-test-products/build.log").read_text(), "build output\n")
        self.assertEqual((diag / "after-test-products/dump.log").read_text(), "retry dump output\n")

    def test_graph_preservation_failure_stops_before_build_or_retry(self) -> None:
        result = self.fx.run_graph(ci=True, graph_rc=48, cp_rc=49)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.fx.swift_calls(), [
            "package --build-system native dump-symbol-graph",
        ])
        diag = self.fx.diagnostics("qinao-symbolgraph-diagnostics.*")[0]
        self.assertEqual((diag / "first-pass/dump.log").read_text(), "first dump failed\n")
        self.assertIn("preservation", (diag / "exits.txt").read_text().lower())

    def test_graph_preservation_search_failure_stops_before_build_or_retry(self) -> None:
        result = self.fx.run_graph(ci=True, graph_rc=53, find_rc=54)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.fx.swift_calls(), [
            "package --build-system native dump-symbol-graph",
        ])
        diag = self.fx.diagnostics("qinao-symbolgraph-diagnostics.*")[0]
        self.assertEqual((diag / "first-pass/dump.log").read_text(), "first dump failed\n")
        self.assertIn("preservation", (diag / "exits.txt").read_text().lower())

    def test_graph_after_phase_staging_failure_prints_first_output_and_stops(self) -> None:
        result = self.fx.run_graph(ci=True, graph_rc=64, after_stage_rc=65)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("first dump failed\n", result.stderr)
        self.assertIn("after-test-products staging failed", result.stderr)
        self.assertEqual(self.fx.swift_calls(), [
            "package --build-system native dump-symbol-graph",
        ])
        self.assertEqual(self.fx.scanner_calls(), [])
        diag = self.fx.diagnostics("qinao-symbolgraph-diagnostics.*")[0]
        self.assertEqual((diag / "first-pass/dump.log").read_text(), "first dump failed\n")
        self.assertEqual(self.fx.graph_bytes(diag, "first-pass"), b"original graph")


class FailureDiagnosticsWorkflowTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fx = DiagnosticsFixture()

    def tearDown(self) -> None:
        self.fx.cleanup()

    def test_actual_test_steps_execute_runner_with_exact_primary_arguments(self) -> None:
        jobs = _parse_yaml(ORDINARY_WORKFLOW.read_text())["jobs"]
        for job_name, mode in (("bas-tests", "bas"), ("qinao-tests", "qinao")):
            with self.subTest(job=job_name):
                fx = DiagnosticsFixture()
                try:
                    step = next(item for item in jobs[job_name]["steps"]
                                if item.get("name") in {"BAS test", "Qinao test"})
                    cwd = fx.root / step.get("working-directory", "")
                    result = subprocess.run(
                        ["/bin/bash", "-e", "-c", step["run"]], cwd=cwd,
                        env=fx.environment(PRIMARY_RC="50"), capture_output=True,
                        text=True, check=False, timeout=10,
                    )
                    self.assertEqual(result.returncode, 50, result.stderr)
                    expected = "test --build-system native"
                    if mode == "bas":
                        expected += " --package-path BehavioralAISubstrate"
                    self.assertEqual(fx.swift_calls()[0], expected)
                finally:
                    fx.cleanup()

    def test_failure_uploads_have_exact_scopes_and_bounded_configuration(self) -> None:
        jobs = _parse_yaml(ORDINARY_WORKFLOW.read_text())["jobs"]
        expected = {
            "bas-tests": ("Upload BAS XCTest failure diagnostics", "bas-xctest", "bas-xctest-diagnostics.*"),
            "qinao-tests": ("Upload Qinao XCTest failure diagnostics", "qinao-xctest", "qinao-xctest-diagnostics.*"),
            "boundary-checks": ("Upload Qinao symbol graph failure diagnostics", "qinao-symbolgraph", "qinao-symbolgraph-diagnostics.*"),
        }
        for job_name, (step_name, artifact, path) in expected.items():
            with self.subTest(job=job_name):
                step = next(item for item in jobs[job_name]["steps"] if item.get("name") == step_name)
                self.assertEqual(step, {
                    "name": step_name,
                    "if": "failure()",
                    "uses": UPLOAD_ACTION,
                    "with": {
                        "name": f"{artifact}-${{{{ github.run_id }}}}-${{{{ github.run_attempt }}}}",
                        "path": f"${{{{ runner.temp }}}}/{path}",
                        "if-no-files-found": "warn",
                        "retention-days": 7,
                        "compression-level": 6,
                    },
                })
        boundary_names = [step.get("name") for step in jobs["boundary-checks"]["steps"]]
        self.assertEqual(boundary_names.index("Upload Qinao symbol graph failure diagnostics"),
                         boundary_names.index("Sovereign redaction") + 1)


if __name__ == "__main__":
    unittest.main()
