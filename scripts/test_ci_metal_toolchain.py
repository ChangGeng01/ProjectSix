from __future__ import annotations

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.test_test_workflow_owner_ledger import ORDINARY_WORKFLOW, _parse_yaml


ROOT = Path(__file__).resolve().parents[1]


class MetalToolchainTests(unittest.TestCase):
    def run_fixture(
        self,
        body: str,
        overrides: dict[str, str] | None = None,
        missing_tools: tuple[str, ...] = (),
    ) -> tuple[subprocess.CompletedProcess[str], list[str]]:
        with tempfile.TemporaryDirectory(prefix="ci-metal-") as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            shutil.copy2(
                ROOT / "scripts/ensure_ci_metal_toolchain.sh",
                root / "scripts/ensure_ci_metal_toolchain.sh",
            )
            (root / "bash").symlink_to("/bin/bash")

            xcode_app = root / "Fixture Xcode With Spaces.app"
            developer_dir = xcode_app / "Contents/Developer"
            direct_launcher = (
                developer_dir
                / "Toolchains/XcodeDefault.xctoolchain/usr/bin/metal"
            )
            stubs = {
                "xcode-select": """[[ $# == 1 && "$1" == -p ]] || exit 64
[[ "$SELECT_RC" == 0 ]] || exit "$SELECT_RC"
selected="${DEVELOPER_DIR:-$SELECTED_DEVELOPER_DIR}"
case "$selected" in
  *.app) selected="$selected/Contents/Developer" ;;
esac
printf "%s\\n" "$selected"
""",
                "xcrun": """[[ $# == 4 && "$1" == --sdk && "$3" == metal && "$4" == --version ]] || exit 64
missing="$MISSING_BEFORE"
[[ ! -e "$STATE" ]] || missing="$MISSING_AFTER"
case " $missing " in
  *" $2 "*) echo "fixture missing Metal for $2" >&2; exit 69 ;;
esac
echo "fixture Metal compiler $2"
""",
                "xcodebuild": """[[ "$*" == "-downloadComponent MetalToolchain" ]] || exit 64
[[ "$DOWNLOAD_RC" == 0 ]] || exit "$DOWNLOAD_RC"
: > "$STATE"
""",
                "metal": """[[ "$*" == "--version" ]] || exit 64
rc="$DIRECT_RC_BEFORE"
[[ ! -e "$STATE" ]] || rc="$DIRECT_RC_AFTER"
if [[ "$rc" != 0 ]]; then
  echo "fixture direct Metal launcher failure" >&2
  exit "$rc"
fi
echo "fixture direct Metal compiler"
""",
            }
            for name, code in stubs.items():
                if name in missing_tools:
                    continue
                path = direct_launcher if name == "metal" else root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(
                    "#!/bin/bash\nset -u\n"
                    f'printf "%s %s\\n" "{name}" "$*" >> "$CALLS"\n'
                    + code,
                    encoding="utf-8",
                )
                path.chmod(0o700)

            # The selector, selected Xcode tree, direct launcher, SDK launcher,
            # and installer are all private fixtures; no host tool can resolve.
            env = {
                "PATH": str(root),
                "CALLS": str(root / "calls"),
                "STATE": str(root / "installed"),
                "DEVELOPER_DIR": str(xcode_app),
                "SELECTED_DEVELOPER_DIR": str(developer_dir),
                "SELECT_RC": "0",
                "MISSING_BEFORE": "",
                "MISSING_AFTER": "",
                "DIRECT_RC_BEFORE": "0",
                "DIRECT_RC_AFTER": "0",
                "DOWNLOAD_RC": "0",
            }
            env.update(overrides or {})
            result = subprocess.run(
                [
                    "/bin/bash",
                    "-e",
                    "-c",
                    body + '\nprintf "product\\n" >> "$CALLS"\n',
                ],
                cwd=root,
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            calls_path = root / "calls"
            calls = calls_path.read_text().splitlines() if calls_path.exists() else []
            return result, calls

    def test_available_compilers_skip_download_for_selected_xcode_path_with_spaces(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh macosx iphonesimulator"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            calls,
            [
                "xcode-select -p",
                "metal --version",
                "xcrun --sdk macosx metal --version",
                "xcrun --sdk iphonesimulator metal --version",
                "product",
            ],
        )

    def test_missing_sdk_compiler_is_installed_once_and_all_sdks_rechecked(self) -> None:
        for missing in ("macosx", "iphonesimulator", "macosx iphonesimulator"):
            with self.subTest(missing=missing):
                result, calls = self.run_fixture(
                    "bash scripts/ensure_ci_metal_toolchain.sh macosx iphonesimulator",
                    {"MISSING_BEFORE": missing},
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    calls,
                    [
                        "xcode-select -p",
                        "metal --version",
                        "xcrun --sdk macosx metal --version",
                        "xcrun --sdk iphonesimulator metal --version",
                        "xcodebuild -downloadComponent MetalToolchain",
                        "metal --version",
                        "xcrun --sdk macosx metal --version",
                        "xcrun --sdk iphonesimulator metal --version",
                        "product",
                    ],
                )
                self.assertIn("fixture missing Metal", result.stderr)

    def test_xcrun_success_direct_launcher_failure_triggers_one_download(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh macosx",
            {"DIRECT_RC_BEFORE": "69"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            calls,
            [
                "xcode-select -p",
                "metal --version",
                "xcrun --sdk macosx metal --version",
                "xcodebuild -downloadComponent MetalToolchain",
                "metal --version",
                "xcrun --sdk macosx metal --version",
                "product",
            ],
        )

    def test_xcrun_resolver_skips_unused_direct_launcher_probe(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh --resolver xcrun macosx",
            {"DIRECT_RC_BEFORE": "69", "DIRECT_RC_AFTER": "69"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            calls,
            [
                "xcode-select -p",
                "xcrun --sdk macosx metal --version",
                "product",
            ],
        )

    def test_xcrun_resolver_installs_once_and_rechecks_only_sdk_probes(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh --resolver xcrun macosx iphonesimulator",
            {"MISSING_BEFORE": "macosx"},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            calls,
            [
                "xcode-select -p",
                "xcrun --sdk macosx metal --version",
                "xcrun --sdk iphonesimulator metal --version",
                "xcodebuild -downloadComponent MetalToolchain",
                "xcrun --sdk macosx metal --version",
                "xcrun --sdk iphonesimulator metal --version",
                "product",
            ],
        )

    def test_xcrun_resolver_post_install_failure_remains_fatal(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh --resolver xcrun macosx",
            {"MISSING_BEFORE": "macosx", "MISSING_AFTER": "macosx"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("product", calls)
        self.assertNotIn("metal --version", calls)
        self.assertEqual(calls.count("xcrun --sdk macosx metal --version"), 2)
        self.assertEqual(
            calls.count("xcodebuild -downloadComponent MetalToolchain"), 1
        )
        self.assertIn(
            "Metal compiler unavailable for macosx after component preparation",
            result.stderr,
        )

    def test_explicit_selected_xcode_resolver_preserves_direct_launcher_checks(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh --resolver selected-xcode macosx"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            calls,
            [
                "xcode-select -p",
                "metal --version",
                "xcrun --sdk macosx metal --version",
                "product",
            ],
        )

    def test_download_failure_stops_without_reprobe_or_product(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh macosx",
            {"MISSING_BEFORE": "macosx", "DOWNLOAD_RC": "42"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(
            calls,
            [
                "xcode-select -p",
                "metal --version",
                "xcrun --sdk macosx metal --version",
                "xcodebuild -downloadComponent MetalToolchain",
            ],
        )
        self.assertIn("Metal Toolchain download failed", result.stderr)

    def test_failed_post_install_sdk_probe_stops_without_product(self) -> None:
        for missing_after in ("macosx", "iphonesimulator"):
            with self.subTest(missing_after=missing_after):
                result, calls = self.run_fixture(
                    "bash scripts/ensure_ci_metal_toolchain.sh macosx iphonesimulator",
                    {"MISSING_BEFORE": "macosx", "MISSING_AFTER": missing_after},
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("product", calls)
                self.assertEqual(
                    calls.count("xcodebuild -downloadComponent MetalToolchain"), 1
                )
                self.assertEqual(
                    calls.count(f"xcrun --sdk {missing_after} metal --version"), 2
                )
                self.assertIn(
                    f"Metal compiler unavailable for {missing_after}", result.stderr
                )

    def test_direct_launcher_still_failing_after_download_stops_product(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh macosx",
            {"DIRECT_RC_BEFORE": "69", "DIRECT_RC_AFTER": "69"},
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("product", calls)
        self.assertEqual(calls.count("metal --version"), 2)
        self.assertEqual(
            calls.count("xcodebuild -downloadComponent MetalToolchain"), 1
        )
        self.assertEqual(calls.count("xcrun --sdk macosx metal --version"), 2)
        self.assertIn("Selected Xcode Metal launcher unavailable", result.stderr)

    def test_invalid_arguments_do_not_run_tools(self) -> None:
        for arguments in (
            "",
            "iphoneos",
            "macosx invalid",
            "'macosx iphonesimulator'",
            "--help",
            "--resolver",
            "--resolver unknown macosx",
            "--resolver xcrun",
            "macosx --resolver xcrun",
        ):
            with self.subTest(arguments=arguments):
                result, calls = self.run_fixture(
                    "bash scripts/ensure_ci_metal_toolchain.sh " + arguments
                )
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertEqual(calls, [])

    def test_selector_failure_or_empty_path_stops_before_probes_and_product(self) -> None:
        cases = (
            ({"SELECT_RC": "71"}, "Could not resolve selected Xcode developer directory"),
            (
                {"DEVELOPER_DIR": "", "SELECTED_DEVELOPER_DIR": ""},
                "Selected Xcode developer directory is empty",
            ),
        )
        for overrides, message in cases:
            with self.subTest(overrides=overrides):
                result, calls = self.run_fixture(
                    "bash scripts/ensure_ci_metal_toolchain.sh macosx", overrides
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(calls, ["xcode-select -p"])
                self.assertIn(message, result.stderr)

    def test_missing_selected_direct_launcher_cannot_produce_success(self) -> None:
        result, calls = self.run_fixture(
            "bash scripts/ensure_ci_metal_toolchain.sh macosx",
            missing_tools=("metal",),
        )
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("product", calls)
        self.assertEqual(calls.count("xcodebuild -downloadComponent MetalToolchain"), 1)
        self.assertIn("Selected Xcode Metal launcher unavailable", result.stderr)

    def test_missing_selector_xcrun_or_xcodebuild_cannot_produce_success(self) -> None:
        for tools in (
            ("xcode-select",),
            ("xcrun",),
            ("xcodebuild",),
            ("xcrun", "xcodebuild"),
        ):
            with self.subTest(tools=tools):
                result, calls = self.run_fixture(
                    "bash scripts/ensure_ci_metal_toolchain.sh macosx",
                    {"MISSING_BEFORE": "macosx"},
                    tools,
                )
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("product", calls)
                self.assertIn("command not found", result.stderr)

    def test_actual_workflow_preparation_steps_execute_guard(self) -> None:
        jobs = _parse_yaml(ORDINARY_WORKFLOW.read_text())["jobs"]
        for job in (
            "bas-tests",
            "qinao-tests",
            "samplehost-tests",
        ):
            steps = [
                step
                for step in jobs[job]["steps"]
                if step.get("name") == "Prepare Metal compiler"
            ]
            self.assertEqual(len(steps), 1)
            for fail in (False, True):
                with self.subTest(job=job, download_fails=fail):
                    result, calls = self.run_fixture(
                        steps[0]["run"],
                        {
                            "MISSING_BEFORE": "macosx",
                            "DOWNLOAD_RC": "42" if fail else "0",
                        },
                    )
                    self.assertEqual(result.returncode == 0, not fail, result.stderr)
                    self.assertEqual("product" in calls, not fail)
                    self.assertEqual(
                        "xcrun --sdk iphonesimulator metal --version" in calls,
                        job == "samplehost-tests",
                    )
                    if job != "samplehost-tests":
                        self.assertNotIn("metal --version", calls)
                    self.assertEqual(
                        calls.count("xcodebuild -downloadComponent MetalToolchain"), 1
                    )

        boundary_names = {
            step.get("name") for step in jobs["boundary-checks"]["steps"]
        }
        self.assertNotIn("Prepare Metal compiler", boundary_names)


if __name__ == "__main__":
    unittest.main()
