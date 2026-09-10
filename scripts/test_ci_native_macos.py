from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

from scripts.test_test_workflow_owner_ledger import ORDINARY_WORKFLOW, _parse_yaml


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/prepare_ci_mlx_metallib.sh"


class MlxMetallibFixture:
    def __init__(self, test: unittest.TestCase) -> None:
        self.test = test
        self.temp = tempfile.TemporaryDirectory(prefix="ci-native-macos-")
        self.root = Path(self.temp.name) / "Repository With Spaces"
        self.scripts = self.root / "scripts"
        self.commands = self.root / "commands"
        self.runner_temp = self.root / "Runner Temp"
        self.github_env = self.root / "GitHub Env"
        self.calls = self.root / "calls.txt"
        self.scripts.mkdir(parents=True)
        self.commands.mkdir()
        self.runner_temp.mkdir()
        self.github_env.touch()
        if HELPER.exists():
            shutil.copy2(HELPER, self.scripts / HELPER.name)

        vendor = (
            self.root
            / "BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx"
        )
        for name in ("mlx", "metal-cpp", "json", "fmt"):
            (vendor / name).mkdir(parents=True)

        (self.commands / "bash").symlink_to("/bin/bash")
        (self.commands / "dirname").symlink_to("/usr/bin/dirname")
        self.make_command(
            "mktemp",
            """
[[ "$#" == 2 && "$1" == -d && "$2" == "$RUNNER_TEMP"/*XXXXXX ]] || exit 64
count=1
[[ ! -f "$MKTEMP_COUNTER" ]] || count=$(( $(< "$MKTEMP_COUNTER") + 1 ))
printf '%s\n' "$count" > "$MKTEMP_COUNTER"
created="${2%XXXXXX}$count"
/bin/mkdir "$created" || exit $?
printf '%s\n' "$created" >> "$MKTEMP_RECEIPT"
printf '%s\n' "$created"
""",
        )
        self.make_command(
            "python3",
            """
printf 'python3 %s\n' "$*" >> "$CALLS"
[[ "$#" == 3 && "$1" == -m && "$2" == venv ]] || exit 64
[[ "${VENV_RC:-0}" == 0 ]] || exit "$VENV_RC"
/bin/mkdir -p "$3/bin"
/bin/cp "$PIP_TEMPLATE" "$3/bin/python"
/bin/cp "$CMAKE_TEMPLATE" "$3/bin/cmake"
/bin/chmod 700 "$3/bin/python" "$3/bin/cmake"
""",
        )
        self.pip_template = self.make_file(
            "pip-template",
            """#!/bin/bash
set -u
printf 'pip %s\n' "$*" >> "$CALLS"
[[ "$*" == "-m pip install --disable-pip-version-check --no-deps cmake==3.31.6" ]] || exit 64
exit "${PIP_RC:-0}"
""",
        )
        self.cmake_template = self.make_file(
            "cmake-template",
            """#!/bin/bash
set -u
printf 'cmake %s\n' "$*" >> "$CALLS"
case "${1:-}" in
  --version)
    [[ "$#" == 1 ]] || exit 64
    printf 'cmake version %s\n' "${CMAKE_VERSION:-3.31.6}"
    exit "${VERSION_RC:-0}"
    ;;
  -S)
    exit "${CONFIGURE_RC:-0}"
    ;;
  --build)
    [[ "$*" == "--build $2 --target mlx-metallib --parallel 8" ]] || exit 64
    [[ "${BUILD_RC:-0}" == 0 ]] || exit "$BUILD_RC"
    artifact="$2/mlx/backend/metal/kernels/mlx.metallib"
    if [[ "${ARTIFACT_MODE:-present}" != missing ]]; then
      /bin/mkdir -p "${artifact%/*}"
      if [[ "$ARTIFACT_MODE" == empty ]]; then
        : > "$artifact"
      else
        printf 'fixture metallib payload\n' > "$artifact"
      fi
    fi
    ;;
  *) exit 64 ;;
esac
""",
        )

    def cleanup(self) -> None:
        self.temp.cleanup()

    def make_file(self, name: str, content: str) -> Path:
        path = self.root / name
        path.write_text(content, encoding="utf-8")
        path.chmod(0o700)
        return path

    def make_command(self, name: str, body: str) -> Path:
        return self.make_file(
            f"commands/{name}", f"#!/bin/bash\nset -u\n{body.strip()}\n"
        )

    def environment(self, **overrides: str) -> dict[str, str]:
        env = {
            "PATH": str(self.commands),
            "RUNNER_TEMP": str(self.runner_temp),
            "GITHUB_ENV": str(self.github_env),
            "CALLS": str(self.calls),
            "MKTEMP_COUNTER": str(self.root / "mktemp-counter"),
            "MKTEMP_RECEIPT": str(self.root / "mktemp-receipt"),
            "PIP_TEMPLATE": str(self.pip_template),
            "CMAKE_TEMPLATE": str(self.cmake_template),
            "VENV_RC": "0",
            "PIP_RC": "0",
            "VERSION_RC": "0",
            "CONFIGURE_RC": "0",
            "BUILD_RC": "0",
            "ARTIFACT_MODE": "present",
        }
        env.update(overrides)
        return env

    def run(
        self,
        arguments: tuple[str, ...] = (),
        **overrides: str,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                "/bin/bash",
                str(self.scripts / "prepare_ci_mlx_metallib.sh"),
                *arguments,
            ],
            cwd=self.root,
            env=self.environment(**overrides),
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )

    def call_lines(self) -> list[str]:
        return self.calls.read_text().splitlines() if self.calls.exists() else []

    def scratch_paths(self) -> list[Path]:
        receipt = self.root / "mktemp-receipt"
        return [Path(line) for line in receipt.read_text().splitlines()] if receipt.exists() else []


class NativeMacOSHelperTests(unittest.TestCase):
    def setUp(self) -> None:
        self.fx = MlxMetallibFixture(self)

    def tearDown(self) -> None:
        self.fx.cleanup()

    def test_success_runs_exact_pinned_commands_and_publishes_nonempty_artifact(self) -> None:
        result = self.fx.run()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        scratches = self.fx.scratch_paths()
        self.assertEqual(len(scratches), 1)
        scratch = scratches[0]
        artifact = scratch / "build/mlx/backend/metal/kernels/mlx.metallib"
        self.assertTrue(artifact.is_file())
        self.assertGreater(artifact.stat().st_size, 0)
        self.assertEqual(
            self.fx.github_env.read_text(), f"MLX_METAL_PATH={artifact}\n"
        )
        vendor = (
            self.fx.root
            / "BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx"
        )
        self.assertEqual(
            self.fx.call_lines(),
            [
                f"python3 -m venv {scratch}/tools",
                "pip -m pip install --disable-pip-version-check --no-deps cmake==3.31.6",
                "cmake --version",
                (
                    f"cmake -S {vendor}/mlx -B {scratch}/build "
                    "-DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 "
                    "-DMLX_BUILD_METAL=ON -DMLX_METAL_JIT=OFF "
                    "-DMLX_BUILD_TESTS=OFF -DMLX_BUILD_EXAMPLES=OFF "
                    "-DMLX_BUILD_BENCHMARKS=OFF -DMLX_BUILD_PYTHON_BINDINGS=OFF "
                    "-DMLX_BUILD_PYTHON_STUBS=OFF -DFETCHCONTENT_FULLY_DISCONNECTED=ON "
                    f"-DFETCHCONTENT_SOURCE_DIR_METAL_CPP={vendor}/metal-cpp "
                    f"-DFETCHCONTENT_SOURCE_DIR_JSON={vendor}/json "
                    f"-DFETCHCONTENT_SOURCE_DIR_FMT={vendor}/fmt"
                ),
                f"cmake --build {scratch}/build --target mlx-metallib --parallel 8",
            ],
        )
        digest = hashlib.sha256(artifact.read_bytes()).hexdigest()
        self.assertIn(f"MLX metallib path: {artifact}\n", result.stdout)
        self.assertIn(f"MLX metallib size: {artifact.stat().st_size} bytes\n", result.stdout)
        self.assertIn(f"MLX metallib SHA-256: {digest}\n", result.stdout)
        self.assertIn("cmake version 3.31.6", result.stdout)

    def test_each_run_uses_a_fresh_retained_scratch(self) -> None:
        first = self.fx.run()
        second = self.fx.run()
        self.assertEqual((first.returncode, second.returncode), (0, 0))
        scratches = self.fx.scratch_paths()
        self.assertEqual(len(scratches), 2)
        self.assertNotEqual(scratches[0], scratches[1])
        self.assertTrue(all(path.is_dir() for path in scratches))
        records = self.fx.github_env.read_text().splitlines()
        self.assertEqual(
            records,
            [f"MLX_METAL_PATH={path}/build/mlx/backend/metal/kernels/mlx.metallib" for path in scratches],
        )

    def test_relative_runner_temp_publishes_an_absolute_artifact_path(self) -> None:
        relative_runner_temp = self.fx.runner_temp.relative_to(self.fx.root)
        result = self.fx.run(RUNNER_TEMP=str(relative_runner_temp))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        record = self.fx.github_env.read_text().strip()
        self.assertTrue(record.startswith("MLX_METAL_PATH="), record)
        artifact = Path(record.removeprefix("MLX_METAL_PATH="))
        self.assertTrue(artifact.is_absolute(), artifact)
        self.assertTrue(artifact.is_file(), artifact)
        self.assertGreater(artifact.stat().st_size, 0)

    def test_argument_and_required_path_errors_fail_before_commands(self) -> None:
        result = self.fx.run(("unexpected",))
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(self.fx.call_lines(), [])
        self.assertEqual(self.fx.github_env.read_text(), "")

        missing_runner = self.fx.run(RUNNER_TEMP=str(self.fx.root / "absent"))
        self.assertNotEqual(missing_runner.returncode, 0)
        self.assertEqual(self.fx.call_lines(), [])
        self.assertEqual(self.fx.github_env.read_text(), "")

        missing_env = self.fx.run(GITHUB_ENV=str(self.fx.root / "absent-env"))
        self.assertNotEqual(missing_env.returncode, 0)
        self.assertEqual(self.fx.call_lines(), [])
        self.assertEqual(self.fx.github_env.read_text(), "")

    def test_missing_vendor_input_fails_without_scratch_or_publication(self) -> None:
        missing = (
            self.fx.root
            / "BehavioralAISubstrate/Vendor/mlx-swift/Source/Cmlx/fmt"
        )
        missing.rmdir()
        result = self.fx.run()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.fx.scratch_paths(), [])
        self.assertEqual(self.fx.call_lines(), [])
        self.assertEqual(self.fx.github_env.read_text(), "")
        self.assertIn(str(missing), result.stderr)

    def test_command_failures_retain_scratch_without_environment_record(self) -> None:
        cases = (
            ("VENV_RC", "31", ["python3 "]),
            ("PIP_RC", "32", ["python3 ", "pip "]),
            ("VERSION_RC", "33", ["python3 ", "pip ", "cmake --version"]),
            ("CONFIGURE_RC", "34", ["python3 ", "pip ", "cmake --version", "cmake -S "]),
            ("BUILD_RC", "35", ["python3 ", "pip ", "cmake --version", "cmake -S ", "cmake --build "]),
        )
        for variable, value, prefixes in cases:
            with self.subTest(variable=variable):
                fx = MlxMetallibFixture(self)
                try:
                    result = fx.run(**{variable: value})
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(len(fx.scratch_paths()), 1)
                    self.assertTrue(fx.scratch_paths()[0].is_dir())
                    self.assertEqual(fx.github_env.read_text(), "")
                    calls = fx.call_lines()
                    self.assertEqual(len(calls), len(prefixes))
                    self.assertTrue(all(call.startswith(prefix) for call, prefix in zip(calls, prefixes)))
                finally:
                    fx.cleanup()

    def test_missing_or_empty_artifact_is_not_published(self) -> None:
        for mode in ("missing", "empty"):
            with self.subTest(mode=mode):
                fx = MlxMetallibFixture(self)
                try:
                    result = fx.run(ARTIFACT_MODE=mode)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertEqual(fx.github_env.read_text(), "")
                    self.assertEqual(len(fx.scratch_paths()), 1)
                finally:
                    fx.cleanup()

    def test_newline_in_scratch_or_output_record_path_is_rejected(self) -> None:
        unsafe_runner = self.fx.root / "Runner\nTemp"
        unsafe_runner.mkdir()
        result = self.fx.run(RUNNER_TEMP=str(unsafe_runner))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("newline", result.stderr.lower())
        self.assertEqual(self.fx.scratch_paths(), [])
        self.assertEqual(self.fx.github_env.read_text(), "")

        unsafe_env = self.fx.root / "GitHub\nEnv"
        unsafe_env.touch()
        result = self.fx.run(GITHUB_ENV=str(unsafe_env))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("newline", result.stderr.lower())
        self.assertEqual(unsafe_env.read_text(), "")


class NativeMacOSWorkflowTests(unittest.TestCase):
    def test_actual_workflow_native_artifact_handoff_uses_real_helper(self) -> None:
        jobs = _parse_yaml(ORDINARY_WORKFLOW.read_text())["jobs"]
        for job_name in ("bas-tests", "qinao-tests"):
            with self.subTest(job=job_name):
                fx = MlxMetallibFixture(self)
                try:
                    steps = jobs[job_name]["steps"]
                    helper_steps = [step for step in steps if step.get("name") == "Prepare MLX metallib"]
                    self.assertEqual(len(helper_steps), 1)
                    helper_result = subprocess.run(
                        ["/bin/bash", "-e", "-c", helper_steps[0]["run"]],
                        cwd=fx.root,
                        env=fx.environment(),
                        capture_output=True,
                        text=True,
                        check=False,
                        timeout=10,
                    )
                    self.assertEqual(helper_result.returncode, 0, helper_result.stderr)
                    record = fx.github_env.read_text().strip()
                    self.assertTrue(record.startswith("MLX_METAL_PATH="), record)
                    mlx_path = record.removeprefix("MLX_METAL_PATH=")
                    fx.make_command(
                        "swift",
                        """
printf 'swift %s\n' "$*" >> "$CALLS"
[[ -n "${MLX_METAL_PATH:-}" && -s "$MLX_METAL_PATH" ]] || exit 72
""",
                    )
                    test_step = next(step for step in steps if step.get("name") in {"BAS test", "Qinao test"})
                    product_result = subprocess.run(
                        ["/bin/bash", "-e", "-c", test_step["run"]],
                        cwd=fx.root,
                        env=fx.environment(MLX_METAL_PATH=mlx_path),
                        capture_output=True,
                        text=True,
                        check=False,
                        timeout=10,
                    )
                    self.assertEqual(product_result.returncode, 0, product_result.stderr)
                    expected = "swift test --build-system native"
                    if job_name == "bas-tests":
                        expected += " --package-path BehavioralAISubstrate"
                    self.assertEqual(fx.call_lines()[-1], expected)
                finally:
                    fx.cleanup()

    def test_boundary_job_selects_native_without_unused_metal_preparation(self) -> None:
        job = _parse_yaml(ORDINARY_WORKFLOW.read_text())["jobs"]["boundary-checks"]
        self.assertEqual(job.get("env"), {"QINAO_SWIFT_BUILD_SYSTEM": "native"})
        names = [step.get("name") for step in job["steps"]]
        self.assertNotIn("Prepare Metal compiler", names)
        helper = next(step for step in job["steps"] if step.get("name") == "CI contract and iOS floor helper tests")
        self.assertIn("scripts.test_ci_native_macos", helper["run"].split())


if __name__ == "__main__":
    unittest.main()
