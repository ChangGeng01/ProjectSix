from __future__ import annotations

import ast
import copy
import base64
import hashlib
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable
from unittest import mock

try:
    from scripts import check_qinao_owner_ledger as checker
except ModuleNotFoundError:  # Direct `python scripts/test_...py` invocation.
    import check_qinao_owner_ledger as checker


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_qinao_owner_ledger.py"
VERIFICATION_TIME = datetime(2026, 7, 30, tzinfo=timezone.utc)
LEDGER = ROOT / "docs" / "superpowers" / "specs" / "qinao-owner-ledger-v1.json"
CREATE_PROOF = {
    "repository_search": "rg found no existing owner",
    "public_primitive": "system primitives provide mechanism only",
    "missing_invariant": "the reviewed invariant is absent",
    "extension_insufficient": "existing owners cannot hold this responsibility",
    "single_owner": "one authority, state, storage, and recovery boundary",
    "dependency_direction": "dependencies point inward to value contracts",
    "compatibility_retirement": "legacy projection has a bounded retirement gate",
    "verification": "mutation, crash, replay, and duplicate-owner checks",
}
GIT_REPOSITORY_LOCATOR_VARIABLES = (
    "GIT_DIR",
    "GIT_WORK_TREE",
    "GIT_INDEX_FILE",
    "GIT_COMMON_DIR",
    "GIT_CEILING_DIRECTORIES",
)


def _isolated_git_environment(
    base_environment: dict[str, str],
    *,
    object_directory: Path,
    alternate_object_directory: Path,
) -> dict[str, str]:
    environment = dict(base_environment)
    for name in GIT_REPOSITORY_LOCATOR_VARIABLES:
        environment.pop(name, None)
    environment.update(
        {
            "GIT_OBJECT_DIRECTORY": str(object_directory),
            "GIT_ALTERNATE_OBJECT_DIRECTORIES": str(alternate_object_directory),
        }
    )
    return environment


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


def _replace_top_level_definition(
    source: str,
    name: str,
    replacement: str,
) -> str:
    tree = ast.parse(source)
    definitions = []
    for statement in tree.body:
        if not isinstance(statement, (ast.Assign, ast.AnnAssign)):
            continue
        targets = (
            statement.targets
            if isinstance(statement, ast.Assign)
            else [statement.target]
        )
        if any(
            isinstance(target, ast.Name) and target.id == name for target in targets
        ):
            definitions.append(statement)
    if len(definitions) != 1:
        raise AssertionError(
            f"expected one top-level definition for {name}, got {len(definitions)}"
        )
    statement = definitions[0]
    lines = source.splitlines(keepends=True)
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line))
    start = offsets[statement.lineno - 1] + statement.col_offset
    end = offsets[statement.end_lineno - 1] + statement.end_col_offset
    return source[:start] + replacement + source[end:]


class QinaoOwnerLedgerCLITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls._wave_fixture_directory = tempfile.TemporaryDirectory()
        cls.WAVE_ARGUMENTS = _make_default_wave_arguments(
            Path(cls._wave_fixture_directory.name)
        )

    @classmethod
    def tearDownClass(cls) -> None:
        cls._wave_fixture_directory.cleanup()

    @staticmethod
    def make_audit_boundary_root(
        directory: str,
        checker_source: str | None = None,
    ) -> Path:
        root = Path(directory)
        for relative_path in (
            "BehavioralAISubstrate/Package.swift",
            "SampleHost/Package.swift",
            "QinaoRuntimeSDK/Package.swift",
            "BehavioralAISubstrate/DeviceTestApp/project.yml",
            "BehavioralAISubstrate/DeviceTestApp/BASDeviceTest.xcodeproj/project.pbxproj",
        ):
            path = root / relative_path
            path.parent.mkdir(parents=True, exist_ok=True)
            comment = (
                "# production build declaration\n"
                if path.suffix in {".yml", ".yaml"}
                else "// production build declaration\n"
            )
            path.write_text(comment, encoding="utf-8")
        checker_path = root / "scripts" / "check_qinao_owner_ledger.py"
        checker_path.parent.mkdir(parents=True, exist_ok=True)
        checker_path.write_text(
            (
                SCRIPT.read_text(encoding="utf-8")
                if checker_source is None
                else checker_source
            ),
            encoding="utf-8",
        )
        return root

    @classmethod
    def run_ledger(cls, ledger: Path) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--root",
                str(ROOT),
                "--ledger",
                str(ledger),
                *cls.WAVE_ARGUMENTS,
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def run_mutated_ledger(
        self,
        mutate: Callable[[dict], None],
    ) -> subprocess.CompletedProcess[str]:
        with LEDGER.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        mutated = copy.deepcopy(data)
        mutate(mutated)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "owner-ledger.json"
            path.write_text(
                json.dumps(mutated, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            return self.run_ledger(path)

    def validate_with_owner_paths_absent(
        self,
        data: dict,
        owner_id: str,
    ) -> list[str]:
        permission = next(
            item for item in data["create_permissions"] if item["owner_id"] == owner_id
        )
        absent_paths = {
            (ROOT / relative_path).resolve(strict=False)
            for relative_path in permission["allowed_paths"]
        }
        original_is_file = Path.is_file

        def selectively_absent(path: Path) -> bool:
            if path.resolve(strict=False) in absent_paths:
                return False
            return original_is_file(path)

        with mock.patch.object(Path, "is_file", new=selectively_absent):
            return checker.validate_ledger(data, ROOT)

    def run_candidate(self, candidate: dict) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "candidate.json"
            path.write_text(
                json.dumps(candidate, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            return subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--root",
                    str(ROOT),
                    "--ledger",
                    str(LEDGER),
                    *self.WAVE_ARGUMENTS,
                    "--candidate-manifest",
                    str(path),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

    def run_ledger_and_candidate(
        self,
        ledger: dict,
        candidate: dict,
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            ledger_path = Path(directory) / "owner-ledger.json"
            candidate_path = Path(directory) / "candidate.json"
            ledger_path.write_text(
                json.dumps(ledger, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            candidate_path.write_text(
                json.dumps(candidate, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
            return subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--root",
                    str(ROOT),
                    "--ledger",
                    str(ledger_path),
                    *self.WAVE_ARGUMENTS,
                    "--candidate-manifest",
                    str(candidate_path),
                ],
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

    def run_candidates(
        self, candidates: list[dict]
    ) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as directory:
            paths: list[Path] = []
            for index, candidate in enumerate(candidates):
                path = Path(directory) / f"candidate-{index:02d}.json"
                path.write_text(
                    json.dumps(candidate, ensure_ascii=False, indent=2),
                    encoding="utf-8",
                )
                paths.append(path)
            command = [
                sys.executable,
                str(SCRIPT),
                "--root",
                str(ROOT),
                "--ledger",
                str(LEDGER),
                *self.WAVE_ARGUMENTS,
            ]
            for path in paths:
                command.extend(["--candidate-manifest", str(path)])
            return subprocess.run(
                command,
                cwd=ROOT,
                capture_output=True,
                text=True,
                check=False,
            )

    def test_repository_owner_ledger_passes_validation(self) -> None:
        completed = self.run_ledger(LEDGER)

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn("owner-ledger: PASS", completed.stdout)

    def test_repository_owner_ledger_runs_under_protected_python_39(
        self,
    ) -> None:
        protected_python = Path("/usr/bin/python3")
        if not protected_python.is_file() or not os.access(protected_python, os.X_OK):
            self.skipTest("protected /usr/bin/python3 is unavailable")
        version = subprocess.run(
            [str(protected_python), "--version"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        observed_version = (version.stdout or version.stderr).strip()
        if version.returncode != 0 or observed_version != "Python 3.9.6":
            self.skipTest(
                "protected /usr/bin/python3 is not exact Python 3.9.6 "
                f"(observed {observed_version or f'exit {version.returncode}'})"
            )
        completed = subprocess.run(
            [
                str(protected_python),
                str(SCRIPT),
                "--root",
                str(ROOT),
                "--ledger",
                str(LEDGER),
                *self.WAVE_ARGUMENTS,
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn("owner-ledger: PASS", completed.stdout)

    def test_audit_asset_boundary_validator_is_installed(self) -> None:
        self.assertTrue(
            hasattr(checker, "validate_audit_asset_boundary"),
            "CreateGate must enforce the audit-asset/production boundary",
        )

    def test_package_manifest_cannot_include_audit_assets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            manifest = root / "QinaoRuntimeSDK" / "Package.swift"
            manifest.write_text(
                '.copy("../scripts/check_qinao_owner_ledger.py")\n',
                encoding="utf-8",
            )

            errors = checker.validate_audit_asset_boundary(root)

        self.assertTrue(
            any(
                "check_qinao_owner_ledger.py" in error
                and "production build surface" in error
                for error in errors
            ),
            errors,
        )

    def test_double_slash_resource_path_cannot_spoof_swift_comment_filter(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            manifest = root / "QinaoRuntimeSDK" / "Package.swift"
            manifest.write_text(
                '.copy("../scripts//check_qinao_owner_ledger.py")\n',
                encoding="utf-8",
            )

            errors = checker.validate_audit_asset_boundary(root)

        self.assertTrue(
            any("check_qinao_owner_ledger.py" in error for error in errors),
            errors,
        )

    def test_comment_only_audit_asset_mentions_are_not_membership(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            manifest = root / "QinaoRuntimeSDK" / "Package.swift"
            manifest.write_text(
                "// check_qinao_owner_ledger.py stays outside production\n"
                "/* qinao-owner-ledger-v1.json is an audit-only contract. */\n",
                encoding="utf-8",
            )

            errors = checker.validate_audit_asset_boundary(root)

        self.assertEqual(errors, [])

    def test_audit_boundary_uses_executed_checker_source_not_root_path(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(
                directory,
                checker_source="pass\n",
            )
            errors = checker.validate_audit_asset_boundary(
                root,
                executed_owner_gate_source=SCRIPT.read_text(encoding="utf-8"),
            )

        self.assertEqual(errors, [])

    def test_direct_checker_source_capture_is_one_fd_snapshot(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source_path = Path(directory) / "bound-checker.py"
            expected = b"print('bound source')\n"
            source_path.write_bytes(expected)
            with (
                mock.patch.object(
                    checker,
                    "__file__",
                    str(source_path),
                ),
                mock.patch(
                    "builtins.open",
                    wraps=open,
                ) as bound_open,
            ):
                captured, error = checker.capture_executed_owner_gate_source()

        self.assertIsNone(error)
        self.assertEqual(captured, expected.decode("utf-8"))
        self.assertEqual(bound_open.call_count, 1)
        self.assertEqual(bound_open.call_args.args[:2], (str(source_path), "rb"))

    def test_xcodegen_project_cannot_include_owner_ledger(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            project = root / "BehavioralAISubstrate" / "DeviceTestApp" / "project.yml"
            project.write_text(
                "targets:\n  BASDeviceTest:\n    sources:\n"
                "      - ../../docs/superpowers/specs/qinao-owner-ledger-v1.json\n",
                encoding="utf-8",
            )

            errors = checker.validate_audit_asset_boundary(root)

        self.assertTrue(
            any(
                "qinao-owner-ledger-v1.json" in error
                and "production build surface" in error
                for error in errors
            ),
            errors,
        )

    def test_xcodegen_project_cannot_include_root_audit_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            project = root / "BehavioralAISubstrate" / "DeviceTestApp" / "project.yml"
            project.write_text(
                "targets:\n  BASDeviceTest:\n    sources:\n"
                "      - path: ../../scripts\n",
                encoding="utf-8",
            )

            errors = checker.validate_audit_asset_boundary(root)

        self.assertTrue(
            any(
                "scripts" in error and "production build surface" in error
                for error in errors
            ),
            errors,
        )

    def test_xcodegen_glob_and_alias_cannot_cover_audit_assets(self) -> None:
        project_sources = {
            "glob": "targets:\n  App:\n    sources:\n      - path: ../../scripts/*.py\n",
            "alias": (
                "auditPath: &auditPath ../../scripts\n"
                "targets:\n  App:\n    sources:\n      - *auditPath\n"
            ),
        }
        for case, source in project_sources.items():
            with self.subTest(case=case):
                with tempfile.TemporaryDirectory() as directory:
                    root = self.make_audit_boundary_root(directory)
                    project = (
                        root / "BehavioralAISubstrate" / "DeviceTestApp" / "project.yml"
                    )
                    project.write_text(source, encoding="utf-8")

                    errors = checker.validate_audit_asset_boundary(root)

                self.assertTrue(
                    any("production build surface" in error for error in errors),
                    errors,
                )

    def test_swift_resource_path_must_be_one_static_literal(self) -> None:
        manifests = {
            "raw-audit-directory": '.copy(#"../scripts"#)\n',
            "dynamic-resource": "let resource = makeResourcePath()\n.copy(resource)\n",
            "factory-alias": ('let include = Resource.copy\ninclude("../scripts")\n'),
            "escaped-separator": '.copy("..\\u{2F}scripts")\n',
        }
        for case, source in manifests.items():
            with self.subTest(case=case):
                with tempfile.TemporaryDirectory() as directory:
                    root = self.make_audit_boundary_root(directory)
                    manifest = root / "QinaoRuntimeSDK" / "Package.swift"
                    manifest.write_text(source, encoding="utf-8")

                    errors = checker.validate_audit_asset_boundary(root)

                self.assertTrue(
                    any("production build surface" in error for error in errors),
                    errors,
                )

    def test_xcodegen_yaml_indirection_is_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            project = root / "BehavioralAISubstrate" / "DeviceTestApp" / "project.yml"
            sources = {
                "absolute-alias": (
                    f'audit: &audit "{(root / "scripts").as_posix()}"\n'
                    "targets:\n  App:\n    sources: [*audit]\n"
                ),
                "unicode-escape": (
                    'targets:\n  App:\n    sources: ["..\\u002F..\\u002Fscripts"]\n'
                ),
            }
            for case, source in sources.items():
                with self.subTest(case=case):
                    project.write_text(source, encoding="utf-8")

                    errors = checker.validate_audit_asset_boundary(root)

                    self.assertTrue(
                        any("production build surface" in error for error in errors),
                        errors,
                    )

    def test_generated_xcode_project_cannot_include_gate_tests(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            project = (
                root
                / "BehavioralAISubstrate"
                / "DeviceTestApp"
                / "BASDeviceTest.xcodeproj"
                / "project.pbxproj"
            )
            project.write_text(
                "test_check_qinao_owner_ledger.py in Resources\n",
                encoding="utf-8",
            )

            errors = checker.validate_audit_asset_boundary(root)

        self.assertTrue(
            any(
                "test_check_qinao_owner_ledger.py" in error
                and "production build surface" in error
                for error in errors
            ),
            errors,
        )

    def test_new_owned_build_surface_is_discovered_automatically(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            manifest = root / "QinaoRuntimeSDK" / "Experimental" / "Package.swift"
            manifest.parent.mkdir(parents=True, exist_ok=True)
            manifest.write_text(
                '.copy("../../scripts")\n',
                encoding="utf-8",
            )

            errors = checker.validate_audit_asset_boundary(root)

        self.assertTrue(
            any(
                "QinaoRuntimeSDK/Experimental/Package.swift" in error
                and "production build surface" in error
                for error in errors
            ),
            errors,
        )

    def test_versioned_swiftpm_and_xcodegen_yaml_surfaces_are_discovered(self) -> None:
        surfaces = {
            "QinaoRuntimeSDK/Package@swift-6.2.swift": ('.copy("../scripts")\n'),
            "QinaoRuntimeSDK/Experimental/project.yaml": (
                "targets:\n  App:\n    sources:\n      - ../../scripts\n"
            ),
            "QinaoRuntimeSDK/Experimental/device-spec.yaml": (
                "name: Device\ntargets:\n  App:\n    sources:\n      - ../../scripts\n"
            ),
        }
        for relative_path, source in surfaces.items():
            with self.subTest(relative_path=relative_path):
                with tempfile.TemporaryDirectory() as directory:
                    root = self.make_audit_boundary_root(directory)
                    surface = root / relative_path
                    surface.parent.mkdir(parents=True, exist_ok=True)
                    surface.write_text(source, encoding="utf-8")

                    errors = checker.validate_audit_asset_boundary(root)

                self.assertTrue(
                    any(
                        relative_path in error and "production build surface" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_vendored_build_surfaces_remain_outside_qinao_ownership(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = self.make_audit_boundary_root(directory)
            manifest = (
                root
                / "BehavioralAISubstrate"
                / "Vendor"
                / "Dependency"
                / "Package.swift"
            )
            manifest.parent.mkdir(parents=True, exist_ok=True)
            manifest.write_text(
                '.copy("../../../../scripts")\n',
                encoding="utf-8",
            )

            errors = checker.validate_audit_asset_boundary(root)

        self.assertEqual(errors, [])

    def test_owner_gate_cannot_emit_swift_sql_or_runtime_configuration(self) -> None:
        emitters = {
            "GeneratedAuthority.swift": (
                "from pathlib import Path\n"
                "Path('GeneratedAuthority.swift').write_text('generated')\n"
            ),
            "generated-schema.sql": (
                "with open('generated-schema.sql', 'w', encoding='utf-8') as handle:\n"
                "    handle.write('generated')\n"
            ),
            "runtime-config.json": (
                "import subprocess\n"
                "subprocess.run(['sh', '-c', 'echo generated > runtime-config.json'])\n"
            ),
            "indirect-runtime-config.json": (
                "from pathlib import Path\n"
                "emit = Path('indirect-runtime-config.json').write_text\n"
                "emit('generated')\n"
            ),
            "import-aliased-subprocess.json": (
                "from subprocess import run as invoke\n"
                "invoke(['sh', '-c', 'echo generated > imported.json'])\n"
            ),
            "import-aliased-open.json": (
                "from builtins import open as sink\n"
                "handle = sink('imported-open.json', 'w')\n"
                "handle.close()\n"
            ),
            "assigned-subprocess.json": (
                "import subprocess\n"
                "runner = subprocess.run\n"
                "runner(['sh', '-c', 'echo generated > assigned.json'])\n"
            ),
            "assigned-path-open.json": (
                "from pathlib import Path\n"
                "sink = Path('assigned-path-open.json').open\n"
                "handle = sink('w')\n"
                "handle.close()\n"
            ),
            "io-open-alias.json": (
                "from io import open as sink\n"
                "handle = sink('io-open-alias.json', 'w')\n"
                "handle.close()\n"
            ),
            "os-open-write.json": (
                "from os import open as fd_open, write as fd_write\n"
                "descriptor = fd_open('os-open-write.json', 65)\n"
                "fd_write(descriptor, b'generated')\n"
            ),
            "dynamic-import.json": (
                "import importlib\n"
                "invoke = importlib.import_module('subprocess').run\n"
                "invoke(['sh', '-c', 'echo generated > dynamic-import.json'])\n"
            ),
            "subprocess-dict.json": (
                "import subprocess\n"
                "runner = subprocess.__dict__['run']\n"
                "runner(['sh', '-c', 'echo generated > subprocess-dict.json'])\n"
            ),
            "path-dict-open.json": (
                "from pathlib import Path\n"
                "opener = Path.__dict__['open']\n"
                "handle = opener(Path('path-dict-open.json'), 'w')\n"
                "handle.close()\n"
            ),
            "globals-registry.json": (
                "import subprocess\n"
                "runner = globals()['subprocess'].run\n"
                "runner(['sh', '-c', 'echo generated > globals-registry.json'])\n"
            ),
            "sys-modules.json": (
                "import subprocess\n"
                "import sys\n"
                "runner = sys.modules['subprocess'].run\n"
                "runner(['sh', '-c', 'echo generated > sys-modules.json'])\n"
            ),
            "path-replace.json": (
                "from pathlib import Path\n"
                "Path('source.tmp').replace('path-replace.json')\n"
            ),
            "subprocess-executable.json": (
                "import subprocess\n"
                "subprocess.run(\n"
                "    ['git', 'cat-file', '-t', 'HEAD'],\n"
                "    executable='./untrusted-writer',\n"
                ")\n"
            ),
            "for-shadowed-print.json": (
                "import subprocess\n"
                "for print in [subprocess.__dict__['run']]:\n"
                "    print(['sh', '-c', 'echo generated > for-shadowed-print.json'])\n"
            ),
            "implicit-path-move.json": (
                "from pathlib import Path\n"
                "class ArtifactPath(\n"
                "    type('ArtifactPath', (Path,), {'__truediv__': Path.move})\n"
                "):\n"
                "    pass\n"
                "ArtifactPath('source.tmp') / 'implicit-path-move.json'\n"
            ),
        }
        for emitted_path, source in emitters.items():
            with self.subTest(emitted_path=emitted_path):
                with tempfile.TemporaryDirectory() as directory:
                    root = self.make_audit_boundary_root(
                        directory,
                        checker_source=source,
                    )

                    errors = checker.validate_audit_asset_boundary(root)

                self.assertTrue(
                    any("read-only" in error for error in errors),
                    errors,
                )

    def test_owner_gate_protects_approved_names_across_all_binding_forms(self) -> None:
        binding_forms = {
            "for": "for print in ():\n    pass\n",
            "async-for": (
                "async def consume(items):\n"
                "    async for print in items:\n"
                "        pass\n"
            ),
            "comprehension": "[None for print in ()]\n",
            "with": ("from pathlib import Path\nwith Path('.') as print:\n    pass\n"),
            "except": "try:\n    pass\nexcept OSError as print:\n    pass\n",
            "lambda": "lambda print: None\n",
            "function": "def print():\n    pass\n",
            "class": "class print:\n    pass\n",
            "delete": "del print\n",
            "qualified-root": (
                "from pathlib import Path\nfor str in [Path]:\n    pass\n"
            ),
        }
        if checker.MATCH_NAME_BINDING_NODE_TYPES:
            binding_forms["match"] = "match 0:\n    case print:\n        pass\n"
        for case, source in binding_forms.items():
            with self.subTest(case=case):
                errors = checker.validate_owner_gate_read_only(source, case)
                self.assertTrue(
                    any("read-only" in error and "bind" in error for error in errors),
                    errors,
                )

    def test_owner_gate_rejects_reflection_and_module_registries_at_source(
        self,
    ) -> None:
        sources = {
            "dunder": ("import subprocess\nhidden = subprocess.__dict__['run']\n"),
            "module-registry": (
                "import subprocess\nimport sys\nhidden = sys.modules['subprocess']\n"
            ),
            "implicit-protocol-call": (
                "from pathlib import Path\n"
                "class ArtifactPath(Path):\n"
                "    __truediv__ = Path.replace\n"
                "ArtifactPath('source.tmp') / 'Generated.swift'\n"
            ),
        }
        for case, source in sources.items():
            with self.subTest(case=case):
                errors = checker.validate_owner_gate_read_only(source, case)
                self.assertTrue(
                    any(
                        "read-only" in error and "reflection" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_owner_gate_rejects_runtime_import_and_argument_registry_mutation(
        self,
    ) -> None:
        sources = {
            "pop-append.py": (
                "import sys\n"
                "while sys.path:\n"
                "    sys.path.pop()\n"
                "sys.path.append('/tmp/attacker')\n"
                "import json\n"
            ),
            "extend.py": (
                "import sys\nsys.path.extend(['/tmp/attacker'])\nimport json\n"
            ),
            "slice-store.py": (
                "import sys\nsys.path[:] = ['/tmp/attacker']\nimport json\n"
            ),
            "alias.py": (
                "import sys\n"
                "paths = sys.path\n"
                "paths.pop()\n"
                "paths.append('/tmp/attacker')\n"
                "import json\n"
            ),
            "argv.py": (
                "import sys\n"
                "while sys.argv:\n"
                "    sys.argv.pop()\n"
                "sys.argv.extend(['--root', '/tmp/attacker'])\n"
            ),
            "argv-alias.py": ("import sys\narguments = sys.argv\narguments.pop()\n"),
        }
        for source_name, source in sources.items():
            with self.subTest(source_name=source_name):
                errors = checker.validate_owner_gate_read_only(
                    source,
                    source_name,
                )
                self.assertTrue(
                    any(
                        "runtime registry 'sys.path'" in error
                        or "runtime registry 'sys.argv'" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_owner_gate_policy_globals_cannot_be_poisoned_before_main(
        self,
    ) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        injection = """
ALLOWED_DIRECT_CALL_NAMES = frozenset({"evil"})
ALLOWED_MODULE_IMPORTS = frozenset()
FORBIDDEN_EMIT_CALLS = frozenset()
READ_ONLY_GIT_SUBCOMMANDS = frozenset({"commit"})
GIT_SUBPROCESS_ENVIRONMENT = (("PATH", "/tmp/attacker"),)
"""
        marker = '\nif __name__ == "__main__":\n'
        self.assertIn(marker, source)
        mutated = source.replace(marker, injection + marker, 1)
        namespace = {
            "__file__": str(SCRIPT),
            "__name__": "test_policy_poisoned_checker",
        }
        exec(compile(mutated, str(SCRIPT), "exec"), namespace)
        poisoned_validator = namespace["validate_owner_gate_read_only"]

        emitted_errors = poisoned_validator(
            "evil()\n",
            "poisoned-emitter.py",
        )
        mutation_errors = poisoned_validator(
            mutated,
            "poisoned-checker.py",
        )
        definition_mutation = source.replace(
            '    "write_text",\n',
            "",
            1,
        )
        self.assertNotEqual(definition_mutation, source)
        definition_errors = poisoned_validator(
            definition_mutation,
            "definition-mutated-checker.py",
        )

        self.assertTrue(
            any("read-only" in error for error in emitted_errors),
            emitted_errors,
        )
        self.assertTrue(
            any("policy" in error and "mutation" in error for error in mutation_errors),
            mutation_errors,
        )
        self.assertTrue(
            any(
                "policy definition freeze mismatch" in error
                for error in definition_errors
            ),
            definition_errors,
        )

    def test_owner_gate_rejects_process_control_on_alternate_receivers(
        self,
    ) -> None:
        sources = {
            "alternate-communicate.py": (
                "def run_bounded_process(evil):\n    evil.communicate(timeout=1)\n"
            ),
            "alternate-kill.py": (
                "def terminate_process_group(evil):\n    evil.kill()\n"
            ),
            "alternate-wait.py": (
                "def terminate_process_group(evil):\n    evil.wait(timeout=1)\n"
            ),
            "alternate-pipe-close.py": (
                "def terminate_process_group(evil):\n    evil.stdout.close()\n"
            ),
        }
        for source_name, source in sources.items():
            with self.subTest(source_name=source_name):
                errors = checker.validate_owner_gate_read_only(
                    source,
                    source_name,
                )
                self.assertTrue(
                    any(
                        "unapproved method/capability" in error
                        or "process control" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_owner_gate_open_calls_are_receiver_aware_and_fail_closed(
        self,
    ) -> None:
        rejected = {
            "path-write.py": (
                "from pathlib import Path\nPath('/tmp/qinao-owned').open('w')\n"
            ),
            "path-expanded-keywords.py": (
                "from pathlib import Path\n"
                "Path('/tmp/qinao-owned').open(**{'mode': 'w'})\n"
            ),
            "unknown-read.py": ("def inspect(unknown):\n    unknown.open('r')\n"),
            "starred-builtins-open.py": "open(*['/tmp/qinao-owned', 'w'])\n",
            "expanded-builtins-open.py": (
                "open('/tmp/qinao-owned', **{'mode': 'w'})\n"
            ),
        }
        for source_name, source in rejected.items():
            with self.subTest(source_name=source_name):
                errors = checker.validate_owner_gate_read_only(
                    source,
                    source_name,
                )
                self.assertTrue(
                    any("read-only" in error for error in errors),
                    errors,
                )

        self.assertEqual(
            checker.validate_owner_gate_read_only(
                "with open('/tmp/qinao-input', 'r', encoding='utf-8') as source:\n"
                "    source.read()\n",
                "direct-read.py",
            ),
            [],
        )

    def test_owner_gate_requires_bounded_read_only_git_runtime_guard(
        self,
    ) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        mutated = source.replace(
            "if not git_command_is_read_only(command):",
            "if git_command_is_read_only(command):",
            1,
        )
        self.assertNotEqual(mutated, source)

        errors = checker.validate_owner_gate_read_only(
            mutated,
            "mutated-checker.py",
        )

        self.assertTrue(
            any("bounded subprocess read-only Git guard" in error for error in errors),
            errors,
        )

    def test_owner_gate_exact_freezes_bounded_process_contract(self) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        mutations = {
            "false-guard-branch": source.replace(
                "    if not git_command_is_read_only(command):\n",
                "    if not git_command_is_read_only(command) or False:\n",
                1,
            ),
            "command-rebind-after-guard": source.replace(
                '        raise OSError("owner gate subprocess is not an allowed '
                'read-only Git command")\n',
                '        raise OSError("owner gate subprocess is not an allowed '
                'read-only Git command")\n'
                '    command = ["git", "cat-file", "-t", "0" * 40]\n',
                1,
            ),
            "environment-rebind": source.replace(
                "    environment = dict(_git_environment_items)\n",
                "    environment = dict(_git_environment_items)\n"
                '    environment = {"PATH": "/tmp/attacker"}\n',
                1,
            ),
            "signature-drift": source.replace(
                "    text: bool,\n) -> subprocess.CompletedProcess:\n",
                "    text: bool,\n"
                "    env: dict | None = None,\n"
                ") -> subprocess.CompletedProcess:\n",
                1,
            ),
        }
        for mutation, mutated in mutations.items():
            with self.subTest(mutation=mutation):
                self.assertNotEqual(mutated, source)
                errors = checker.validate_owner_gate_read_only(
                    mutated,
                    checker.OWNER_GATE_RELATIVE_PATH,
                )
                self.assertTrue(
                    any("exact bounded process contract" in error for error in errors),
                    errors,
                )

    def test_exact_function_freezes_are_cross_python_version_stable(
        self,
    ) -> None:
        probe = (
            "from pathlib import Path\n"
            "from scripts import check_qinao_owner_ledger as checker\n"
            "source = Path('scripts/check_qinao_owner_ledger.py').read_text("
            "encoding='utf-8')\n"
            "errors = checker.validate_owner_gate_read_only("
            "source, checker.OWNER_GATE_RELATIVE_PATH)\n"
            "if errors:\n"
            "    raise SystemExit('\\n'.join(errors))\n"
        )
        candidates = (
            Path("/usr/bin/python3"),
            Path.home() / ".local/bin/python3.12",
            Path(sys.executable),
        )
        tested: set[Path] = set()
        for candidate in candidates:
            if not candidate.is_file():
                continue
            resolved = candidate.resolve()
            if resolved in tested:
                continue
            tested.add(resolved)
            with self.subTest(interpreter=str(candidate)):
                completed = subprocess.run(
                    [str(candidate), "-c", probe],
                    cwd=ROOT,
                    capture_output=True,
                    text=True,
                    check=False,
                )
                self.assertEqual(
                    completed.returncode,
                    0,
                    completed.stderr,
                )
        self.assertTrue(tested)

    def test_runtime_git_command_grammar_accepts_only_exact_templates(
        self,
    ) -> None:
        self.assertTrue(
            hasattr(checker, "git_command_is_read_only"),
            "the bounded runner needs one closed runtime Git argv grammar",
        )
        object_id = "a" * 40
        tree = "b" * 64
        path = "BehavioralAISubstrate/Sources/Runtime.swift"
        accepted = (
            ["git", "cat-file", "-t", "a" * 7],
            ["git", "cat-file", "-t", object_id],
            ["git", "cat-file", "blob", object_id],
            ["git", "rev-parse", f"{object_id}^{{tree}}"],
            ["git", "ls-tree", "-z", tree, "--", path],
            ["git", "ls-tree", "-r", "-z", tree],
            [
                "git",
                "diff-tree",
                "--no-commit-id",
                "--no-renames",
                "--raw",
                "-r",
                "-z",
                object_id,
                tree,
            ],
        )
        for command in accepted:
            with self.subTest(accepted=command):
                self.assertTrue(checker.git_command_is_read_only(command))

        rejected = (
            ["git", "cat-file", "-t", object_id, "--help"],
            ["git", "cat-file", "blob", object_id, "--filters"],
            ["git", "rev-parse", object_id],
            ["git", "rev-parse", f"{object_id}^{{tree}}", "--verify"],
            ["git", "ls-tree", tree, "-z", "--", path],
            ["git", "ls-tree", "-z", tree, "--", "../escape"],
            ["git", "ls-tree", "-r", "-z", tree, "--name-only"],
            [
                "git",
                "diff-tree",
                "--no-commit-id",
                "--no-renames",
                "--raw",
                "-r",
                "-z",
                object_id,
                tree,
                "--stat",
            ],
            [
                "git",
                "diff-tree",
                "--no-renames",
                "--no-commit-id",
                "--raw",
                "-r",
                "-z",
                object_id,
                tree,
            ],
            ["git", "-c", "core.pager=cat", "cat-file", "-t", object_id],
            ["git", "cat-file", "-t", "a" * 6],
            ["git", "cat-file", "-t", "A" * 40],
            ["git", "cat-file", "-t", b"a" * 40],
            ["git", "cat-file", "-t", None],
            ["git", "ls-tree", "-z", tree, "--", b"safe/path"],
            ("git", "cat-file", "-t", object_id),
        )
        for command in rejected:
            with self.subTest(rejected=command):
                self.assertFalse(checker.git_command_is_read_only(command))

    def test_owner_git_snapshot_ignores_replacement_refs_and_lazy_fetch(
        self,
    ) -> None:
        environment = dict(checker.GIT_SUBPROCESS_ENVIRONMENT)
        self.assertEqual(environment.get("GIT_NO_REPLACE_OBJECTS"), "1")
        self.assertEqual(environment.get("GIT_NO_LAZY_FETCH"), "1")
        self.assertEqual(environment.get("GIT_OPTIONAL_LOCKS"), "0")
        self.assertEqual(environment.get("GIT_ATTR_NOSYSTEM"), "1")
        self.assertEqual(environment.get("GIT_LITERAL_PATHSPECS"), "1")
        self.assertEqual(environment.get("XDG_CONFIG_HOME"), "/nonexistent")
        self.assertEqual(environment.get("GIT_PAGER"), "cat")
        self.assertEqual(environment.get("PAGER"), "cat")
        self.assertEqual(environment.get("GIT_CONFIG_COUNT"), "5")
        self.assertEqual(environment.get("GIT_CONFIG_KEY_4"), "submodule.recurse")
        self.assertEqual(environment.get("GIT_CONFIG_VALUE_4"), "false")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def git(*arguments: str) -> str:
                return subprocess.run(
                    ["git", *arguments],
                    cwd=root,
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout.strip()

            git("init", "-q")
            git("config", "user.email", "test-only@example.invalid")
            git("config", "user.name", "Qinao Test Only")
            (root / "value.txt").write_text("first\n", encoding="utf-8")
            git("add", "value.txt")
            git("commit", "-qm", "first")
            original_commit = git("rev-parse", "HEAD")
            original_tree = git("rev-parse", "HEAD^{tree}")
            (root / "value.txt").write_text("second\n", encoding="utf-8")
            git("commit", "-qam", "second")
            replacement_commit = git("rev-parse", "HEAD")
            self.assertNotEqual(
                git("rev-parse", f"{replacement_commit}^{{tree}}"),
                original_tree,
            )
            git("replace", original_commit, replacement_commit)

            self.assertEqual(
                checker.git_commit_tree(root, original_commit),
                original_tree,
            )

    def test_static_git_command_grammar_matches_runtime_templates(self) -> None:
        object_id = "a" * 40
        tree = "b" * 64
        path = "BehavioralAISubstrate/Sources/Runtime.swift"
        accepted = (
            ["git", "cat-file", "-t", "a" * 7],
            ["git", "cat-file", "-t", object_id],
            ["git", "cat-file", "blob", object_id],
            ["git", "rev-parse", f"{object_id}^{{tree}}"],
            ["git", "ls-tree", "-z", tree, "--", path],
            ["git", "ls-tree", "-r", "-z", tree],
            [
                "git",
                "diff-tree",
                "--no-commit-id",
                "--no-renames",
                "--raw",
                "-r",
                "-z",
                object_id,
                tree,
            ],
        )
        rejected = (
            ["git", "cat-file", "-t", "a" * 6],
            ["git", "cat-file", "-t", object_id, "--help"],
            ["git", "cat-file", "blob", object_id, "--filters"],
            ["git", "rev-parse", object_id],
            ["git", "ls-tree", tree, "-z", "--", path],
            ["git", "ls-tree", "-z", tree, "--", "../escape"],
            ["git", "ls-tree", "-r", "-z", tree, "--name-only"],
            [
                "git",
                "diff-tree",
                "--no-commit-id",
                "--no-renames",
                "--raw",
                "-r",
                "-z",
                object_id,
                tree,
                "--stat",
            ],
        )

        def audited_call(command: object) -> ast.Call:
            expression = (
                "run_bounded_process("
                f"{command!r}, "
                "cwd=root, timeout_seconds=GIT_TIMEOUT_SECONDS, "
                "stdout_limit_bytes=GIT_STDOUT_LIMIT_BYTES, "
                "stderr_limit_bytes=GIT_STDERR_LIMIT_BYTES, text=True)"
            )
            statement = ast.parse(expression).body[0]
            self.assertIsInstance(statement, ast.Expr)
            self.assertIsInstance(statement.value, ast.Call)
            return statement.value

        for command in accepted:
            with self.subTest(accepted=command):
                self.assertTrue(
                    checker.bounded_process_call_is_read_only(audited_call(command))
                )
        for command in rejected:
            with self.subTest(rejected=command):
                self.assertFalse(
                    checker.bounded_process_call_is_read_only(audited_call(command))
                )

    def test_owner_gate_exact_freezes_git_command_grammar_helper(self) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        helper_marker = (
            "def git_command_is_read_only(command: object) -> bool:\n"
            "    if type(command) is not list"
        )
        self.assertIn(helper_marker, source)
        mutations = {
            "helper-body": source.replace(
                helper_marker,
                "def git_command_is_read_only(command: object) -> bool:\n"
                "    return True\n"
                "    if type(command) is not list",
                1,
            ),
            "grammar-literal": source.replace(
                '{"-t", "blob"}',
                '{"--batch", "blob"}',
                1,
            ),
        }
        for mutation, mutated in mutations.items():
            with self.subTest(mutation=mutation):
                self.assertNotEqual(mutated, source)
                errors = checker.validate_owner_gate_read_only(
                    mutated,
                    checker.OWNER_GATE_RELATIVE_PATH,
                )
                self.assertTrue(
                    any("exact Git command grammar" in error for error in errors),
                    errors,
                )

    def test_owner_gate_exact_freezes_candidate_blob_timeout_contract(
        self,
    ) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        mutations = {
            "loader-hard-cap": source.replace(
                "or timeout_seconds > GIT_TIMEOUT_SECONDS",
                "or False",
                1,
            ),
            "audit-callsite-scope": source.replace(
                'and keyword_values["timeout_seconds"].id == "timeout_seconds"',
                'and isinstance(keyword_values["timeout_seconds"], ast.Name)',
                1,
            ),
        }
        expected_functions = {
            "loader-hard-cap": "load_candidate_blob",
            "audit-callsite-scope": (
                "bounded_candidate_blob_process_call_is_read_only"
            ),
        }
        for mutation, mutated in mutations.items():
            with self.subTest(mutation=mutation):
                self.assertNotEqual(mutated, source)
                errors = checker.validate_owner_gate_read_only(
                    mutated,
                    checker.OWNER_GATE_RELATIVE_PATH,
                )
                self.assertTrue(
                    any(
                        "exact Git command grammar contract" in error
                        and expected_functions[mutation] in error
                        for error in errors
                    ),
                    errors,
                )

    def test_owner_gate_policy_definitions_are_exact_complete_and_unique(
        self,
    ) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        self.assertEqual(
            checker.validate_owner_gate_read_only(source, str(SCRIPT)),
            [],
        )
        policy_names = (
            "ALLOWED_DIRECT_CALL_NAMES",
            "ALLOWED_FROM_IMPORTS",
            "ALLOWED_METHOD_CALLS",
            "ALLOWED_MODULE_IMPORTS",
            "ALLOWED_QUALIFIED_CALLS",
            "DANGEROUS_ALIAS_MODULES",
            "DANGEROUS_ALIAS_TARGETS",
            "FILESYSTEM_WRITE_METHODS",
            "FORBIDDEN_EMIT_CALLS",
            "FORBIDDEN_REFLECTION_REGISTRIES",
            "GIT_SUBPROCESS_ENVIRONMENT",
            "PROTECTED_IMPORTED_NAMES",
            "PROTECTED_QUALIFIED_ROOTS",
            "READ_ONLY_GIT_SUBCOMMANDS",
            "SUBPROCESS_CALLS",
        )
        for name in policy_names:
            with self.subTest(name=name, mutation="value-drift"):
                mutated = _replace_top_level_definition(
                    source,
                    name,
                    f"{name} = frozenset()",
                )
                errors = checker.validate_owner_gate_read_only(
                    mutated,
                    checker.OWNER_GATE_RELATIVE_PATH,
                )
                self.assertTrue(
                    any(
                        "policy definition freeze mismatch" in error for error in errors
                    ),
                    errors,
                )

        with_missing = _replace_top_level_definition(
            source,
            "FORBIDDEN_EMIT_CALLS",
            "",
        )
        with_duplicate = _replace_top_level_definition(
            source,
            "FORBIDDEN_EMIT_CALLS",
            "FORBIDDEN_EMIT_CALLS = frozenset()\nFORBIDDEN_EMIT_CALLS = frozenset()",
        )
        with_member_added = _replace_top_level_definition(
            source,
            "FORBIDDEN_EMIT_CALLS",
            'FORBIDDEN_EMIT_CALLS = frozenset({"os.remove", "os.remove.extra"})',
        )
        with_member_deleted = _replace_top_level_definition(
            source,
            "FORBIDDEN_EMIT_CALLS",
            'FORBIDDEN_EMIT_CALLS = frozenset({"os.remove"})',
        )
        for mutation, mutated in (
            ("missing", with_missing),
            ("duplicate", with_duplicate),
            ("member-added", with_member_added),
            ("member-deleted", with_member_deleted),
        ):
            with self.subTest(mutation=mutation):
                errors = checker.validate_owner_gate_read_only(
                    mutated,
                    checker.OWNER_GATE_RELATIVE_PATH,
                )
                self.assertTrue(
                    any("policy definition freeze" in error for error in errors),
                    errors,
                )

    def test_owner_gate_rejects_recursive_policy_reference_paths(self) -> None:
        source = SCRIPT.read_text(encoding="utf-8")
        marker = '\nif __name__ == "__main__":\n'
        self.assertIn(marker, source)
        attacks = {
            "environment-subscript-store": (
                'GIT_SUBPROCESS_ENVIRONMENT["PATH"] = "/tmp/attacker"\n'
            ),
            "environment-subscript-delete": (
                'del GIT_SUBPROCESS_ENVIRONMENT["PATH"]\n'
            ),
            "environment-subscript-augassign": (
                'GIT_SUBPROCESS_ENVIRONMENT["PATH"] += ":/tmp/attacker"\n'
            ),
            "nested-set-add": ('ALLOWED_FROM_IMPORTS["os"].add(("remove", None))\n'),
            "tuple-receiver": ('(ALLOWED_METHOD_CALLS,)[0].add("write_text")\n'),
            "list-receiver": ('[ALLOWED_METHOD_CALLS][0].add("write_text")\n'),
            "dict-receiver": (
                '{"policy": ALLOWED_METHOD_CALLS}["policy"].update({"write_text"})\n'
            ),
            "helper-poison": (
                "def poison(policy):\n"
                '    policy.add("write_text")\n'
                "poison(ALLOWED_METHOD_CALLS)\n"
            ),
            "return-alias": ("def leak_policy():\n    return FORBIDDEN_EMIT_CALLS\n"),
            "default-alias": (
                "def leak_policy(policy=FORBIDDEN_EMIT_CALLS):\n    return None\n"
            ),
            "tuple-alias": "captured = (FORBIDDEN_EMIT_CALLS,)\n",
            "list-alias": "captured = [FORBIDDEN_EMIT_CALLS]\n",
            "dict-alias": 'captured = {"policy": FORBIDDEN_EMIT_CALLS}\n',
            "comprehension-alias": (
                "captured = [policy for policy in (FORBIDDEN_EMIT_CALLS,)]\n"
            ),
            "walrus-alias": ("captured = ((policy := FORBIDDEN_EMIT_CALLS),)\n"),
        }
        for attack_name, injection in attacks.items():
            with self.subTest(attack=attack_name):
                mutated = source.replace(marker, "\n" + injection + marker, 1)
                errors = checker.validate_owner_gate_read_only(
                    mutated,
                    f"{attack_name}.py",
                )
                self.assertTrue(
                    any("policy" in error for error in errors),
                    errors,
                )

    def test_owner_gate_runtime_decisions_ignore_rebound_policy_globals(
        self,
    ) -> None:
        cases = (
            (
                {"ALLOWED_DIRECT_CALL_NAMES": frozenset({"evil"})},
                "evil()\n",
            ),
            (
                {"ALLOWED_MODULE_IMPORTS": frozenset({"socket"})},
                "import socket\n",
            ),
            (
                {
                    "ALLOWED_FROM_IMPORTS": {
                        "socket": {("socket", None)},
                    },
                },
                "from socket import socket\n",
            ),
            (
                {"ALLOWED_METHOD_CALLS": frozenset({"destroy"})},
                "victim.destroy()\n",
            ),
            (
                {"ALLOWED_QUALIFIED_CALLS": frozenset({"victim.destroy"})},
                "victim.destroy()\n",
            ),
            (
                {"DANGEROUS_ALIAS_MODULES": frozenset()},
                "alias = json\n",
            ),
            (
                {"DANGEROUS_ALIAS_TARGETS": frozenset()},
                "alias = open\n",
            ),
            (
                {"FILESYSTEM_WRITE_METHODS": frozenset()},
                "victim.write_text('owned')\n",
            ),
            (
                {
                    "ALLOWED_QUALIFIED_CALLS": frozenset({"os.remove"}),
                    "FORBIDDEN_EMIT_CALLS": frozenset(),
                },
                "os.remove('/tmp/owned')\n",
            ),
            (
                {"FORBIDDEN_REFLECTION_REGISTRIES": frozenset()},
                "import sys\nsys.path\n",
            ),
            (
                {
                    "PROTECTED_IMPORTED_NAMES": frozenset(),
                    "PROTECTED_QUALIFIED_ROOTS": frozenset(),
                },
                "json = 1\n",
            ),
            (
                {"SUBPROCESS_CALLS": frozenset()},
                "import subprocess\nsubprocess.run([])\n",
            ),
        )
        for patches, candidate in cases:
            with self.subTest(patches=sorted(patches)):
                with mock.patch.multiple(checker, **patches):
                    errors = checker.validate_owner_gate_read_only(
                        candidate,
                        "rebound-policy.py",
                    )
                self.assertTrue(errors)

    def test_owner_gate_policy_snapshots_are_not_keyword_injectable(
        self,
    ) -> None:
        injected_snapshots = {
            "_allowed_direct_call_names": frozenset(),
            "_allowed_from_imports": frozenset(),
            "_allowed_method_calls": frozenset(),
            "_allowed_module_imports": frozenset(),
            "_allowed_qualified_calls": frozenset(),
            "_dangerous_alias_modules": frozenset(),
            "_dangerous_alias_targets": frozenset(),
            "_filesystem_write_methods": frozenset(),
            "_forbidden_emit_calls": frozenset(),
            "_forbidden_reflection_registries": frozenset(),
            "_git_environment_items": (),
            "_protected_imported_names": frozenset(),
            "_protected_qualified_roots": frozenset(),
            "_read_only_git_subcommands": frozenset(),
            "_subprocess_calls": frozenset(),
            "_policy_binding_names": frozenset(),
        }
        for parameter, injected in injected_snapshots.items():
            with self.subTest(parameter=parameter):
                with self.assertRaises(TypeError):
                    checker.validate_owner_gate_read_only(
                        "pass\n",
                        "snapshot-injection.py",
                        **{parameter: injected},
                    )

        with self.assertRaises(TypeError):
            checker.validate_owner_gate_read_only(
                "os.remove('/tmp/owned')\n",
                "snapshot-bypass.py",
                _allowed_qualified_calls=frozenset({"os.remove"}),
                _forbidden_emit_calls=frozenset(),
            )

    def test_owner_gate_identity_is_derived_from_trusted_source_name(
        self,
    ) -> None:
        trusted_names = (
            checker.OWNER_GATE_RELATIVE_PATH,
            str(SCRIPT),
            "/private/tmp/candidate/scripts/check_qinao_owner_ledger.py",
        )
        for source_name in trusted_names:
            for candidate in ("", "pass\n"):
                with self.subTest(
                    source_name=source_name,
                    candidate=repr(candidate),
                ):
                    errors = checker.validate_owner_gate_read_only(
                        candidate,
                        source_name,
                    )
                    self.assertTrue(
                        any(
                            "exactly one validate_owner_gate_read_only" in error
                            for error in errors
                        ),
                        errors,
                    )
                    self.assertTrue(
                        any("policy definition freeze" in error for error in errors),
                        errors,
                    )

        duplicate_validator = (
            "def validate_owner_gate_read_only(contents, source_name):\n"
            "    return []\n"
            "def validate_owner_gate_read_only(contents, source_name):\n"
            "    return []\n"
        )
        errors = checker.validate_owner_gate_read_only(
            duplicate_validator,
            checker.OWNER_GATE_RELATIVE_PATH,
        )
        self.assertTrue(
            any(
                "exactly one validate_owner_gate_read_only" in error for error in errors
            ),
            errors,
        )

        self.assertEqual(
            checker.validate_owner_gate_read_only("", "snippet.py"),
            [],
        )
        self.assertEqual(
            checker.validate_owner_gate_read_only("pass\n", "snippet.py"),
            [],
        )

    def test_bounded_process_owns_git_policy_and_environment(self) -> None:
        with mock.patch.object(
            checker,
            "READ_ONLY_GIT_SUBCOMMANDS",
            frozenset({"status"}),
        ):
            with self.assertRaises(OSError):
                checker.run_bounded_process(
                    ["git", "status"],
                    cwd=ROOT,
                    timeout_seconds=1,
                    stdout_limit_bytes=1024,
                    stderr_limit_bytes=1024,
                    text=True,
                )

        with self.assertRaises(TypeError):
            checker.run_bounded_process(
                ["git", "cat-file", "-t", "0" * 40],
                cwd=ROOT,
                env={"PATH": "/tmp/attacker"},
                timeout_seconds=1,
                stdout_limit_bytes=1024,
                stderr_limit_bytes=1024,
                text=True,
            )
        with self.assertRaises(TypeError):
            checker.run_bounded_process(
                ["git", "cat-file", "-t", "0" * 40],
                cwd=ROOT,
                timeout_seconds=1,
                stdout_limit_bytes=1024,
                stderr_limit_bytes=1024,
                text=True,
                _git_environment_items=(("PATH", "/tmp/attacker"),),
            )

    def test_bounded_process_rejects_stdout_at_cap_plus_one(self) -> None:
        commit = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

        with self.assertRaises(checker.ProcessOutputLimitExceeded):
            checker.run_bounded_process(
                ["git", "rev-parse", f"{commit}^{{tree}}"],
                cwd=ROOT,
                timeout_seconds=5,
                stdout_limit_bytes=40,
                stderr_limit_bytes=1024,
                text=False,
            )

    def test_owner_gate_rejects_process_control_outside_supervisor(self) -> None:
        sources = {
            "signal-group.py": (
                "import os\n"
                "import signal\n"
                "def attack(process):\n"
                "    os.killpg(process.pid, signal.SIGKILL)\n"
            ),
            "kill-child.py": ("def attack(process):\n    process.kill()\n"),
        }
        for source_name, source in sources.items():
            with self.subTest(source_name=source_name):
                errors = checker.validate_owner_gate_read_only(
                    source,
                    source_name,
                )
                self.assertTrue(
                    any(
                        "process control is outside the bounded supervisor" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_ledger_validation_runs_audit_asset_boundary(self) -> None:
        with LEDGER.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        sentinel = "audit boundary sentinel"

        with mock.patch.object(
            checker,
            "validate_audit_asset_boundary",
            return_value=[sentinel],
        ):
            errors = checker.validate_ledger(data, ROOT)

        self.assertIn(sentinel, errors)

    def test_missing_owner_must_be_explicitly_allowlisted(self) -> None:
        def mutate(data: dict) -> None:
            duplicate = copy.deepcopy(data["owners"][0])
            duplicate["owner_id"] = "unapproved.new-owner"
            duplicate["classification"] = "M"
            data["owners"].append(duplicate)

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("unapproved.new-owner", completed.stderr)
        self.assertIn("create_allowlist", completed.stderr)

    def test_create_allowlist_contains_exactly_missing_owners(self) -> None:
        def mutate(data: dict) -> None:
            data["create_allowlist"].append("identity.semantic-layers")

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("create_allowlist", completed.stderr)
        self.assertIn("exactly", completed.stderr)

    def test_create_allowlist_and_permissions_follow_owner_card_order(self) -> None:
        def mutate(data: dict) -> None:
            data["create_allowlist"].reverse()
            data["create_permissions"].reverse()

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("canonical M owner order", completed.stderr)

    def test_missing_owner_lifecycle_status_tracks_created_paths(self) -> None:
        with LEDGER.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        owner = next(
            item for item in data["owners"] if item["owner_id"] == "artifact.mesh"
        )
        owner["status"] = "converging"

        errors = self.validate_with_owner_paths_absent(data, "artifact.mesh")

        rendered = "\n".join(errors)
        self.assertIn("M lifecycle status 'converging'", rendered)
        self.assertIn("at least one approved path", rendered)

    def test_implemented_missing_owner_requires_all_approved_paths(self) -> None:
        with LEDGER.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        owner = next(
            item for item in data["owners"] if item["owner_id"] == "artifact.mesh"
        )
        owner["status"] = "implemented"

        errors = self.validate_with_owner_paths_absent(data, "artifact.mesh")

        rendered = "\n".join(errors)
        self.assertIn("M lifecycle status 'implemented'", rendered)
        self.assertIn("every approved path", rendered)

    def test_implemented_missing_owner_requires_resolved_conflicts(self) -> None:
        def mutate(data: dict) -> None:
            owner = next(
                item
                for item in data["owners"]
                if item["owner_id"] == "release.spool-publication"
            )
            owner["status"] = "implemented"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("M lifecycle status 'implemented'", completed.stderr)
        self.assertIn("current_conflicts to be empty", completed.stderr)

    def test_created_missing_owner_path_must_become_owner_evidence(self) -> None:
        def mutate(data: dict) -> None:
            permission = next(
                item
                for item in data["create_permissions"]
                if item["owner_id"] == "artifact.mesh"
            )
            permission["allowed_paths"] = ["scripts/check_qinao_owner_ledger.py"]
            owner = next(
                item for item in data["owners"] if item["owner_id"] == "artifact.mesh"
            )
            owner["status"] = "converging"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("created approved path", completed.stderr)
        self.assertIn("evidence_paths", completed.stderr)

    def test_missing_owner_card_names_its_approved_authority_symbol(self) -> None:
        def mutate(data: dict) -> None:
            owner = next(
                item for item in data["owners"] if item["owner_id"] == "artifact.mesh"
            )
            owner["authority_owner"] = "generic artifact identity owner"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("approved authority_symbol", completed.stderr)
        self.assertIn("BASArtifactStorePort", completed.stderr)

    def test_history_relocation_status_requires_matching_file_evidence(self) -> None:
        def mutate(data: dict) -> None:
            owner = next(
                item
                for item in data["owners"]
                if item["owner_id"] == "history.doctrine-metadata"
            )
            owner["status"] = "implemented"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("history relocation status 'implemented'", completed.stderr)
        self.assertIn("BASHistoryAudit", completed.stderr)
        self.assertIn("current_conflicts", completed.stderr)

    def test_unapproved_candidate_create_is_rejected_with_incumbent_owner(self) -> None:
        completed = self.run_candidate(
            {
                "schema_version": 1,
                "owner_id": "identity.semantic-layers",
                "classification": "M",
                "candidate_path": "BehavioralAISubstrate/Sources/BASRuntimeCore/DuplicateLayerIdentity.swift",
                "authority_symbol": "DuplicateLayerIdentity",
                "create_proof_task": "unreviewed:Task 1",
                "create_proof": CREATE_PROOF,
            }
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("identity.semantic-layers", completed.stderr)
        self.assertIn("BASCognitiveLayer", completed.stderr)

    def test_reviewed_missing_owner_candidate_passes_exact_gate(self) -> None:
        completed = self.run_candidate(
            {
                "schema_version": 1,
                "owner_id": "artifact.mesh",
                "classification": "M",
                "candidate_path": "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift",
                "authority_symbol": "BASArtifactStorePort",
                "create_proof_task": "contracts-layercell:Task 2",
                "create_proof": CREATE_PROOF,
            }
        )

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn("candidates=1", completed.stdout)

    def test_every_allowlisted_production_path_passes_one_combined_create_gate(
        self,
    ) -> None:
        with LEDGER.open("r", encoding="utf-8") as handle:
            ledger = json.load(handle)
        candidates = [
            {
                "schema_version": 1,
                "owner_id": permission["owner_id"],
                "classification": "M",
                "candidate_path": candidate_path,
                "authority_symbol": permission["authority_symbol"],
                "create_proof_task": permission["create_proof_task"],
                "create_proof": CREATE_PROOF,
            }
            for permission in ledger["create_permissions"]
            for candidate_path in permission["allowed_paths"]
        ]

        completed = self.run_candidates(candidates)

        self.assertEqual(
            completed.returncode,
            0,
            msg=f"stdout:\n{completed.stdout}\nstderr:\n{completed.stderr}",
        )
        self.assertIn(f"candidates={len(candidates)}", completed.stdout)

    def test_candidate_path_and_all_eight_proof_fields_are_exact(self) -> None:
        incomplete_proof = dict(CREATE_PROOF)
        del incomplete_proof["verification"]
        completed = self.run_candidate(
            {
                "schema_version": 1,
                "owner_id": "artifact.mesh",
                "classification": "M",
                "candidate_path": "BehavioralAISubstrate/Sources/BASRuntimeCore/RenamedArtifactMesh.swift",
                "authority_symbol": "BASArtifactStorePort",
                "create_proof_task": "contracts-layercell:Task 2",
                "create_proof": incomplete_proof,
            }
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("not allowlisted", completed.stderr)
        self.assertIn("create_proof fields", completed.stderr)

    def test_candidate_create_proof_must_be_substantive_and_non_repeated(self) -> None:
        completed = self.run_candidate(
            {
                "schema_version": 1,
                "owner_id": "artifact.mesh",
                "classification": "M",
                "candidate_path": "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift",
                "authority_symbol": "BASArtifactStorePort",
                "create_proof_task": "contracts-layercell:Task 2",
                "create_proof": {field: "same" for field in CREATE_PROOF},
            }
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("substantive", completed.stderr)
        self.assertIn("distinct", completed.stderr)

    def test_duplicate_owner_id_is_rejected(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"].append(copy.deepcopy(data["owners"][0]))

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("duplicate owner_id", completed.stderr)

    def test_critical_authority_owner_cannot_be_removed(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"] = [
                owner
                for owner in data["owners"]
                if owner["owner_id"] != "state.k3-control-nucleus"
            ]

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("critical owner", completed.stderr)
        self.assertIn("state.k3-control-nucleus", completed.stderr)

    def test_architecture_cardinality_is_exact(self) -> None:
        def mutate(data: dict) -> None:
            data["architecture"]["semantic_layers"].pop()

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("semantic_layers", completed.stderr)
        self.assertIn("expected 14", completed.stderr)

    def test_architecture_identities_are_exact_not_only_cardinal(self) -> None:
        def mutate(data: dict) -> None:
            data["architecture"]["semantic_layers"][0] = "X1"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("semantic_layers", completed.stderr)
        self.assertIn("exact identities", completed.stderr)

    def test_projection_cannot_claim_authority_or_mutability(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0]["allowed_projections"][0]["authority"] = True

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("projection", completed.stderr)
        self.assertIn("authority=false", completed.stderr)

    def test_owner_card_requires_storage_and_recovery_owners(self) -> None:
        def mutate(data: dict) -> None:
            del data["owners"][0]["storage_owner"]

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("storage_owner", completed.stderr)

    def test_owner_card_requires_writer_and_forbidden_rules(self) -> None:
        def mutate(data: dict) -> None:
            del data["owners"][0]["single_writer_required"]
            data["owners"][0]["forbidden"] = []

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("single_writer_required", completed.stderr)
        self.assertIn("forbidden", completed.stderr)

    def test_owner_evidence_paths_must_exist(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0]["evidence_paths"] = ["missing/evidence.swift"]

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("missing/evidence.swift", completed.stderr)

    def test_owner_card_rejects_placeholder_text(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0]["retirement_gate"] = "TODO later"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("placeholder", completed.stderr)

    def test_duplicate_json_key_is_rejected_before_validation(self) -> None:
        raw = LEDGER.read_text(encoding="utf-8").replace(
            '"schema_version": 1,',
            '"schema_version": 1,\n  "schema_version": 2,',
            1,
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate-key-owner-ledger.json"
            path.write_text(raw, encoding="utf-8")
            completed = self.run_ledger(path)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("duplicate JSON key", completed.stderr)

    def test_schema_and_ledger_identity_are_pinned(self) -> None:
        def mutate(data: dict) -> None:
            data["schema_version"] = 2
            data["ledger_id"] = "alternate-owner-ledger"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("schema_version", completed.stderr)
        self.assertIn("ledger_id", completed.stderr)

    def test_boolean_is_not_accepted_as_ledger_schema_version_one(self) -> None:
        def mutate(data: dict) -> None:
            data["schema_version"] = True

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("schema_version must be exactly integer 1", completed.stderr)

    def test_boolean_is_not_accepted_as_candidate_schema_version_one(self) -> None:
        completed = self.run_candidate(
            {
                "schema_version": True,
                "owner_id": "artifact.mesh",
                "classification": "M",
                "candidate_path": "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift",
                "authority_symbol": "BASArtifactStorePort",
                "create_proof_task": "contracts-layercell:Task 2",
                "create_proof": CREATE_PROOF,
            }
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn(
            "candidate schema_version must be exactly integer 1",
            completed.stderr,
        )

    def test_generated_from_head_must_resolve_to_a_git_commit(self) -> None:
        def mutate(data: dict) -> None:
            data["generated_from_head"] = "f" * 40

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("must resolve to a Git commit", completed.stderr)

    def test_generated_from_head_rejects_a_resolvable_non_commit_object(self) -> None:
        tracked_spec = (
            "docs/superpowers/specs/"
            "2026-07-14-iphone-air-future-apple-silicon-architecture-design.md"
        )
        blob_id = subprocess.run(
            ["git", "rev-parse", f"HEAD:{tracked_spec}"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()

        def mutate(data: dict) -> None:
            data["generated_from_head"] = blob_id

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("must resolve to a Git commit", completed.stderr)

    def test_planning_status_and_architecture_spec_are_pinned(self) -> None:
        def mutate(data: dict) -> None:
            data["status"] = "revise"
            data["architecture_spec"] = "docs/superpowers/specs/alternate.md"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("status", completed.stderr)
        self.assertIn("architecture_spec", completed.stderr)

    def test_minimum_ios_is_pinned_to_27(self) -> None:
        def mutate(data: dict) -> None:
            data["minimum_ios"] = "26.0"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("minimum_ios", completed.stderr)
        self.assertIn("27.0", completed.stderr)

    def test_owner_classification_and_work_package_are_declared(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0]["classification"] = "NEW"
            data["owners"][0]["work_package"] = "W99"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("classification", completed.stderr)
        self.assertIn("W99", completed.stderr)

    def test_missing_owner_work_package_is_pinned_to_its_create_proof_task(
        self,
    ) -> None:
        def mutate(data: dict) -> None:
            owner = next(
                item for item in data["owners"] if item["owner_id"] == "artifact.mesh"
            )
            owner["work_package"] = "W6"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("approved Create work-package assignment", completed.stderr)
        self.assertIn("contracts-layercell:Task 2", completed.stderr)
        self.assertIn("W1", completed.stderr)

    def test_every_owner_work_package_is_pinned_to_the_reviewed_wave(self) -> None:
        def mutate(data: dict) -> None:
            owner = next(
                item
                for item in data["owners"]
                if item["owner_id"] == "identity.semantic-layers"
            )
            owner["work_package"] = "W4"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("reviewed owner work-package assignment", completed.stderr)
        self.assertIn("identity.semantic-layers", completed.stderr)
        self.assertIn("W1", completed.stderr)

    def test_every_owner_classification_is_pinned_to_the_reviewed_card(self) -> None:
        def mutate(data: dict) -> None:
            owner = next(
                item
                for item in data["owners"]
                if item["owner_id"] == "provider.package-boundary"
            )
            owner["classification"] = "E"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("reviewed owner classification", completed.stderr)
        self.assertIn("provider.package-boundary", completed.stderr)
        self.assertIn("A", completed.stderr)

    def test_owner_authority_boundaries_are_pinned_to_the_reviewed_card(self) -> None:
        def mutate(data: dict) -> None:
            runtime_owner = next(
                item
                for item in data["owners"]
                if item["owner_id"] == "runtime.turn-operation"
            )
            runtime_owner["authority_owner"] = (
                "BASTurnRuntimeEngine owns the durable K3 head and final result"
            )
            zone_c_owner = next(
                item
                for item in data["owners"]
                if item["owner_id"] == "effect.zone-c-saga"
            )
            zone_c_owner["mutable_state_owner"] = (
                "Zone C owns K3 outbox, stage, seal, and activation"
            )

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("reviewed owner boundary", completed.stderr)
        self.assertIn("runtime.turn-operation", completed.stderr)
        self.assertIn("effect.zone-c-saga", completed.stderr)

    def test_owner_cards_follow_the_canonical_reviewed_order(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0], data["owners"][1] = (
                data["owners"][1],
                data["owners"][0],
            )

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("canonical reviewed owner order", completed.stderr)

    def test_owner_status_is_declared(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0]["status"] = "hand_wavy"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("status", completed.stderr)
        self.assertIn("hand_wavy", completed.stderr)

    def test_approved_missing_status_is_reserved_exactly_for_m_owners(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0]["status"] = "approved_missing"
            first_missing = next(
                owner for owner in data["owners"] if owner["classification"] == "M"
            )
            first_missing["status"] = "planned"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("approved_missing", completed.stderr)
        self.assertIn("classification M", completed.stderr)

    def test_rule_vocabularies_are_exact_and_cannot_self_authorize(self) -> None:
        def mutate(data: dict) -> None:
            data["rules"]["classification_values"].append("NEW")
            data["rules"]["disposition_values"].append("coexist")

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("classification_values", completed.stderr)
        self.assertIn("disposition_values", completed.stderr)

    def test_redundancy_doctrine_cannot_be_weakened_in_data_only(self) -> None:
        def mutate(data: dict) -> None:
            data["rules"]["doctrine"] = "multiple authorities are acceptable"
            data["rules"]["allowed_redundancy"].append("second mutable owner")
            data["rules"]["forbidden_redundancy"].pop()

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("rules.doctrine", completed.stderr)
        self.assertIn("rules.allowed_redundancy", completed.stderr)
        self.assertIn("rules.forbidden_redundancy", completed.stderr)

    def test_conflict_disposition_must_be_declared(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0]["current_conflicts"][0]["disposition"] = "coexist"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("disposition", completed.stderr)
        self.assertIn("coexist", completed.stderr)

    def test_work_packages_and_retrieval_waves_use_separate_exact_namespaces(
        self,
    ) -> None:
        def mutate(data: dict) -> None:
            data["implementation_work_packages"][0]["id"] = "R0"
            data["retrieval_waves"][0]["id"] = "W0"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("W0-W6", completed.stderr)
        self.assertIn("R0-R6", completed.stderr)

    def test_work_package_meanings_are_exact(self) -> None:
        def mutate(data: dict) -> None:
            data["implementation_work_packages"][2]["name"] = "k4_before_k3"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("work package meanings", completed.stderr)
        self.assertIn("W2", completed.stderr)

    def test_work_package_exit_gates_are_pinned(self) -> None:
        def mutate(data: dict) -> None:
            data["implementation_work_packages"][2]["exit_gate"] = (
                "K4 and Zone C may activate state before K3 exists"
            )

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("reviewed exit gate", completed.stderr)
        self.assertIn("W2", completed.stderr)

    def test_master_work_package_rows_are_pinned(self) -> None:
        master = (
            ROOT / "docs/superpowers/plans/"
            "2026-07-15-iphone-air-architecture-convergence-master.md"
        ).read_text(encoding="utf-8")
        mutated = master.replace(
            "Runtime Task 5 Steps 5A–5B's direct/synthetic-effect retirement",
            "Runtime effect work",
            1,
        )

        errors = checker.validate_master_work_package_rows(mutated)

        self.assertTrue(
            any("master work-package W5" in error for error in errors),
            msg=f"errors={errors!r}",
        )

    def test_create_permission_paths_stay_in_the_pinned_task_section(self) -> None:
        def mutate(data: dict) -> None:
            permission = next(
                item
                for item in data["create_permissions"]
                if item["owner_id"] == "artifact.mesh"
            )
            permission["allowed_paths"] = [
                "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/"
                "BASTurnOperationRefTests.swift"
            ]

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("pinned Create task section", completed.stderr)
        self.assertIn("Task 2", completed.stderr)

    def test_create_permission_path_allowlist_is_pinned(self) -> None:
        def mutate(data: dict) -> None:
            permission = next(
                item
                for item in data["create_permissions"]
                if item["owner_id"] == "artifact.mesh"
            )
            permission["allowed_paths"] = [
                "BehavioralAISubstrate/Tests/BehavioralAISubstrateTests/"
                "BASArtifactMeshTests.swift"
            ]

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("reviewed Create permission", completed.stderr)
        self.assertIn("artifact.mesh", completed.stderr)

    def test_create_proof_cannot_move_to_a_later_task_part_or_wave(self) -> None:
        path = "BehavioralAISubstrate/Sources/BASRuntimeCore/BASSemanticTurnDAG.swift"
        reviewed_heading = checker.EXPECTED_CREATE_TASK_HEADINGS["runtime.semantic-dag"]
        relocated = f"""
{reviewed_heading}

- Read: `{path}`

### Task 1 — Part B [W6, only after W5]: Runtime wiring

runtime.semantic-dag
BASSemanticTurnDAG
Create Proof
- Create: `{path}`
"""
        correct = f"""
{reviewed_heading}

runtime.semantic-dag
BASSemanticTurnDAG
Create Proof
- Create: `{path}`

### Task 1 — Part B [W6, only after W5]: Runtime wiring

- Read: `{path}`
"""

        self.assertIsNone(
            checker.reviewed_create_task_section(
                relocated,
                "runtime.semantic-dag",
                "runtime-replay-certification:Task 1",
                "BASSemanticTurnDAG",
                [path],
            )
        )
        self.assertIsNotNone(
            checker.reviewed_create_task_section(
                correct,
                "runtime.semantic-dag",
                "runtime-replay-certification:Task 1",
                "BASSemanticTurnDAG",
                [path],
            )
        )

    def test_retrieval_wave_meanings_are_exact(self) -> None:
        def mutate(data: dict) -> None:
            data["retrieval_waves"][0]["name"] = "retrieve_then_filter"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("retrieval wave meanings", completed.stderr)
        self.assertIn("R0", completed.stderr)

    def test_controlled_document_must_contain_every_required_term(self) -> None:
        def mutate(data: dict) -> None:
            data["controlled_documents"] = [
                {
                    "path": data["architecture_spec"],
                    "required_terms": ["term-that-does-not-exist-in-the-spec"],
                }
            ]

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("controlled document", completed.stderr)
        self.assertIn("term-that-does-not-exist-in-the-spec", completed.stderr)

    def test_controlled_documents_keep_mandatory_baseline_terms(self) -> None:
        def mutate(data: dict) -> None:
            data["controlled_documents"][0]["required_terms"].remove(
                "scripts/check_qinao_owner_ledger.py"
            )
            data["controlled_documents"][1]["required_terms"].remove(
                "BASArtifactScopeBinding"
            )
            data["controlled_documents"][2]["required_terms"].remove(
                "BASSiliconExecutionBinding"
            )
            data["controlled_documents"][3]["required_terms"].remove(
                "BASProviderBranchChainPayload"
            )
            data["controlled_documents"][6]["required_terms"].remove(
                "BASGovernedArtifactPayloadCodec"
            )

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("mandatory baseline terms", completed.stderr)
        self.assertIn("BASArtifactScopeBinding", completed.stderr)
        self.assertIn("BASGovernedArtifactPayloadCodec", completed.stderr)
        self.assertIn("BASSiliconExecutionBinding", completed.stderr)
        self.assertIn("BASProviderBranchChainPayload", completed.stderr)

    def test_first_governed_schema_contracts_reject_fictional_history(self) -> None:
        contents = {
            checker.EXPECTED_CONTROLLED_DOCUMENTS[3]: (
                "The first-governed BASSystemSnapshot 1.0.0 shape is final.\n"
            ),
            checker.EXPECTED_CONTROLLED_DOCUMENTS[4]: (
                "The first-governed BASRuntimeAuditProjectionsBundle 1.0.0 "
                "shape is final.\n"
            ),
            checker.EXPECTED_CONTROLLED_DOCUMENTS[6]: (
                "The first-governed BASTurnRuntimeAuditEnvelope 1.0.0 shape is final.\n"
            ),
        }

        self.assertEqual(
            checker.validate_first_governed_schema_contracts(contents),
            [],
        )

        contents[checker.EXPECTED_CONTROLLED_DOCUMENTS[4]] += (
            "Construct current 1.1.0 BASRuntimeAuditProjectionsBundle from "
            "the legacy fixture.\n"
        )
        contents[checker.EXPECTED_CONTROLLED_DOCUMENTS[3]] += (
            "Legacy missing-schema bytes decode as 1.0.0 before the "
            "BASSystemSnapshot put.\n"
        )
        errors = checker.validate_first_governed_schema_contracts(contents)

        self.assertTrue(
            any("BASRuntimeAuditProjectionsBundle" in item for item in errors)
        )
        self.assertTrue(any("missing-schema" in item for item in errors))

    def test_same_run_audit_outcome_has_one_runtime_owner(self) -> None:
        contents = {
            checker.EXPECTED_CONTROLLED_DOCUMENTS[4]: (
                "Consume the BASSameRunAuditOutcome contract declared by "
                "Runtime Task 1B.\n"
            ),
            checker.EXPECTED_CONTROLLED_DOCUMENTS[6]: (
                "package struct BASSameRunAuditOutcome: Sendable {\n"
                "    package let result: BASEBrainTurnResult\n"
                "    package let auditProjections: BASRuntimeAuditProjectionsBundle\n"
                "}\n"
            ),
        }

        self.assertEqual(
            checker.validate_same_run_audit_outcome_ownership(contents),
            [],
        )

        contents[checker.EXPECTED_CONTROLLED_DOCUMENTS[4]] += (
            "package struct BASSameRunAuditOutcome {}\n"
        )
        errors = checker.validate_same_run_audit_outcome_ownership(contents)

        self.assertTrue(
            any("exactly one Runtime-owned declaration" in item for item in errors)
        )

    def test_memory_finalization_fence_must_precede_checkpoint_put(self) -> None:
        valid = """### Task 4A: Migrate Memory Content

Then call `beginMemoryContentFinalization` and persist `.finalizing` with the
frozen final head and finalization-fence epoch. No checkpoint Artifact is
constructed or put before this commit.

After that durable commit, construct, central-codec ordinary-put, reopen,
identity/equality-check one governed checkpoint. A mismatch rolls back while
leaving the durable finalizing fence installed.
"""
        contents = {checker.EXPECTED_CONTROLLED_DOCUMENTS[4]: valid}

        self.assertEqual(
            checker.validate_memory_content_finalization_contract(contents),
            [],
        )

        invalid = valid.replace(
            "Then call `beginMemoryContentFinalization`",
            "construct, central-codec ordinary-put a checkpoint first. "
            "Then call `beginMemoryContentFinalization`",
        )
        errors = checker.validate_memory_content_finalization_contract(
            {checker.EXPECTED_CONTROLLED_DOCUMENTS[4]: invalid}
        )

        self.assertTrue(any("must precede checkpoint put" in item for item in errors))

    def test_silicon_descriptor_wave_has_one_w1_owner(self) -> None:
        valid = """### Task 3: Consume the frozen descriptor parent

Task 3 byte-consumes the Task 7 W1 contract without changing it.

### Task 7: Build the runtime operation

The W1 value-contract slice owns the frozen constructor inventory, registry entry,
and backward_v1 fixture before any W4 descriptor-parent put.

public enum BASProviderContainmentClass: String, Codable, Sendable {}
public struct BASPersistedOrganDescriptorPayload: Codable, Sendable {}
"""
        contents = {checker.EXPECTED_CONTROLLED_DOCUMENTS[3]: valid}

        self.assertEqual(
            checker.validate_silicon_descriptor_wave_ownership(contents),
            [],
        )

        invalid = valid.replace(
            "Task 3 byte-consumes the Task 7 W1 contract without changing it.",
            "Task 3 extends BASOrganDescriptor and declares the parent.\n"
            "public struct BASPersistedOrganDescriptorPayload: Codable, Sendable {}",
        ).replace(
            "public enum BASProviderContainmentClass: String, Codable, Sendable {}\n"
            "public struct BASPersistedOrganDescriptorPayload: Codable, Sendable {}",
            "public enum BASProviderContainmentClass: String, Codable, Sendable {}",
        )
        errors = checker.validate_silicon_descriptor_wave_ownership(
            {checker.EXPECTED_CONTROLLED_DOCUMENTS[3]: invalid}
        )

        self.assertTrue(any("Task 7/W1" in item for item in errors))
        self.assertTrue(any("stale Task-3 ownership" in item for item in errors))

    def test_value_declarations_must_live_in_their_preludes(self) -> None:
        runtime = """### Task 2 [W6]
- [ ] **Prelude [must commit before Task 1B]: Freeze values**
public enum BASSemanticShadowUnavailableReason: Hashable {}
public enum BASSemanticShadowProjectionDisposition: Hashable {}
public struct BASSemanticShadowObservation: Hashable {}
BASTurnRuntimeAuditEnvelope retains its existing Hashable conformance.
- [ ] **Step 1: Test**
- [ ] **Step 3: Populate the frozen observation**
"""
        semantic = """### Task 8 [W6]
- [ ] **Prelude [before Runtime Task 1B]: Freeze values**
public struct BASSemanticStateShadowObservation {}
public struct BASRuntimeAuditProjectionsBundle {}
- [ ] **Step 1: Test**
- [ ] **Step 3: Wire behavior**
"""
        contents = {
            checker.EXPECTED_CONTROLLED_DOCUMENTS[4]: semantic,
            checker.EXPECTED_CONTROLLED_DOCUMENTS[6]: runtime,
        }

        self.assertEqual(
            checker.validate_value_prelude_declaration_ownership(contents),
            [],
        )

        invalid_runtime = runtime.replace(
            "public struct BASSemanticShadowObservation {}\n",
            "",
        ).replace(
            "- [ ] **Step 3: Populate the frozen observation**",
            "- [ ] **Step 3: Populate the frozen observation**\n"
            "public struct BASSemanticShadowObservation {}",
        )
        errors = checker.validate_value_prelude_declaration_ownership(
            {
                checker.EXPECTED_CONTROLLED_DOCUMENTS[4]: semantic,
                checker.EXPECTED_CONTROLLED_DOCUMENTS[6]: invalid_runtime,
            }
        )

        self.assertTrue(any("value prelude" in item for item in errors))

        non_hashable_runtime = runtime.replace(
            "public struct BASSemanticShadowObservation: Hashable {}",
            "public struct BASSemanticShadowObservation {}",
        )
        errors = checker.validate_value_prelude_declaration_ownership(
            {
                checker.EXPECTED_CONTROLLED_DOCUMENTS[4]: semantic,
                checker.EXPECTED_CONTROLLED_DOCUMENTS[6]: non_hashable_runtime,
            }
        )

        self.assertTrue(any("Hashable" in item for item in errors))

    def test_runtime_envelope_new_fields_keep_explicit_defaults(self) -> None:
        valid = """
semanticDAGArtifactID = nil
orderedSemanticNodeReceiptArtifactIDs = []
legacyStagePlanWasFrozenProjection = false
semanticShadowObservation = nil
runtimeAuditProjectionsBundleArtifactID = nil
authoritativeResultArtifactID = nil
replayManifestArtifactID = nil
publicationCapabilityUseReceiptArtifactID = nil
publicationSinkReceiptArtifactID = nil
"""
        contents = {checker.EXPECTED_CONTROLLED_DOCUMENTS[6]: valid}

        self.assertEqual(
            checker.validate_runtime_envelope_initializer_defaults(contents),
            [],
        )

        errors = checker.validate_runtime_envelope_initializer_defaults(
            {
                checker.EXPECTED_CONTROLLED_DOCUMENTS[6]: valid.replace(
                    "publicationSinkReceiptArtifactID = nil\n",
                    "",
                )
            }
        )

        self.assertTrue(
            any("publicationSinkReceiptArtifactID" in item for item in errors)
        )

    def test_controlled_documents_keep_mandatory_boundary_terms(self) -> None:
        def mutate(data: dict) -> None:
            data["controlled_documents"][0]["required_terms"].remove(
                "BASProviderEgressBoundaryPermit"
            )
            data["controlled_documents"][1]["required_terms"].remove(
                "BASProviderAttemptExecutor.executeExactlyOnce"
            )
            data["controlled_documents"][2]["required_terms"].remove(
                "BASProviderBranchControlPort"
            )
            data["controlled_documents"][3]["required_terms"].remove("TurnBranchRef")
            data["controlled_documents"][4]["required_terms"].remove(
                "BASProviderBranchPolicy"
            )
            data["controlled_documents"][5]["required_terms"].remove(
                "publication_permit_pending"
            )
            for document_index in (5, 6):
                required_terms = data["controlled_documents"][document_index][
                    "required_terms"
                ]
                if "finalizedPublicationRecord(for:)" in required_terms:
                    required_terms.remove("finalizedPublicationRecord(for:)")
            data["controlled_documents"][6]["required_terms"].remove(
                "BASProviderReleaseEvidenceReference"
            )
            data["controlled_documents"][0]["required_terms"].remove(
                "QinaoPreparedEffectContextResolver"
            )
            data["controlled_documents"][5]["required_terms"].remove(
                "QinaoSovereignEffectExecutor"
            )
            data["controlled_documents"][5]["required_terms"].remove(
                "BASEffectBrokerExecution"
            )
            data["controlled_documents"][6]["required_terms"].remove(
                "outbox.effectRequestArtifactID"
            )

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("mandatory document-specific terms", completed.stderr)
        self.assertIn("BASProviderBranchControlPort", completed.stderr)
        self.assertIn("TurnBranchRef", completed.stderr)
        self.assertIn("BASProviderBranchPolicy", completed.stderr)
        self.assertIn("publication_permit_pending", completed.stderr)
        self.assertIn("BASProviderEgressBoundaryPermit", completed.stderr)
        self.assertIn("BASProviderAttemptExecutor.executeExactlyOnce", completed.stderr)
        self.assertIn("BASProviderReleaseEvidenceReference", completed.stderr)
        self.assertIn("finalizedPublicationRecord(for:)", completed.stderr)
        self.assertIn("QinaoPreparedEffectContextResolver", completed.stderr)
        self.assertIn("QinaoSovereignEffectExecutor", completed.stderr)
        self.assertIn("BASEffectBrokerExecution", completed.stderr)
        self.assertIn("outbox.effectRequestArtifactID", completed.stderr)

    def test_controlled_documents_keep_rsi_retrieval_and_horizon_terms(self) -> None:
        removals = {
            0: [
                "BASBudgetLeasePayload",
                "BASBudgetLeaseControlPort",
                "BASBudgetUseReceipt",
                "BASControlLoopEnvelopePayload",
                "BASControlLoopProgressWitnessPayload",
                "BASControlLoopTerminalReceiptPayload",
            ],
            1: ["BASBudgetLeasePayload", "convergedVerified"],
            2: ["BASControlLoopTerminalReceiptPayload", "convergedVerified"],
            4: [
                "R0 compiled_pre_physical_eligibility",
                "R1 sql_metadata_exact_fts_bm25",
                "BASCalendarPolicyPayload",
                "BASMemoryHorizonManifestPayload",
                "MemoryHorizonPersistenceCore.swift",
            ],
            5: ["BASBudgetLeaseControlPort", "BASBudgetUseReceipt"],
            6: [
                "BASBudgetUseReceipt",
                "BASControlLoopEnvelopePayload",
                "BASControlLoopProgressWitnessPayload",
                "BASControlLoopTerminalReceiptPayload",
                "convergedVerified",
                "BASK3ActivatedStateEvidence",
                "history.doctrine-metadata",
                "BASHistoryAudit",
                "relocation_candidate",
            ],
        }

        def mutate(data: dict) -> None:
            for document_index, terms in removals.items():
                required_terms = data["controlled_documents"][document_index][
                    "required_terms"
                ]
                for term in terms:
                    if term in required_terms:
                        required_terms.remove(term)

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("mandatory document-specific terms", completed.stderr)
        self.assertIn("BASBudgetLeasePayload", completed.stderr)
        self.assertIn("BASControlLoopTerminalReceiptPayload", completed.stderr)
        self.assertIn("R0 compiled_pre_physical_eligibility", completed.stderr)
        self.assertIn("R1 sql_metadata_exact_fts_bm25", completed.stderr)
        self.assertIn("BASMemoryHorizonManifestPayload", completed.stderr)
        self.assertIn("convergedVerified", completed.stderr)
        self.assertIn("BASK3ActivatedStateEvidence", completed.stderr)
        self.assertIn("history.doctrine-metadata", completed.stderr)

    def test_sovereign_plan_keeps_persisted_schema_closure_terms(self) -> None:
        def mutate(data: dict) -> None:
            required_terms = data["controlled_documents"][5]["required_terms"]
            required_terms.remove("BASSchemaVersioned")
            required_terms.remove("BASEBrainSchemaGovernanceRegistry")

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("mandatory document-specific terms", completed.stderr)
        self.assertIn("BASSchemaVersioned", completed.stderr)
        self.assertIn("BASEBrainSchemaGovernanceRegistry", completed.stderr)

    def test_create_permission_is_reproduced_exactly_in_its_domain_plan(self) -> None:
        def mutate(data: dict) -> None:
            data["create_permissions"][0]["create_proof_task"] = "drifted:Task 99"

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("domain plan", completed.stderr)
        self.assertIn("drifted:Task 99", completed.stderr)

    def test_controlled_documents_reject_duplicates_and_forbidden_terms(self) -> None:
        def mutate(data: dict) -> None:
            duplicate = copy.deepcopy(data["controlled_documents"][0])
            duplicate["forbidden_terms"] = ["iOS 27"]
            data["controlled_documents"].append(duplicate)

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("exactly once and in canonical order", completed.stderr)
        self.assertIn("forbidden term", completed.stderr)

    def test_projection_and_conflict_schema_is_not_extensible_by_accident(self) -> None:
        def mutate(data: dict) -> None:
            data["owners"][0]["allowed_projections"][0]["source_watermark_required"] = (
                "sometimes"
            )
            del data["owners"][0]["current_conflicts"][0]["reason"]

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("source_watermark_required", completed.stderr)
        self.assertIn("conflict", completed.stderr)
        self.assertIn("reason", completed.stderr)

    def test_malformed_collection_shapes_fail_without_a_traceback(self) -> None:
        def mutate(data: dict) -> None:
            data["architecture"] = []
            data["owners"] = {}

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("architecture must be an object", completed.stderr)
        self.assertIn("owners must be a list", completed.stderr)
        self.assertNotIn("Traceback", completed.stderr)

    def test_malformed_nested_values_fail_without_a_traceback(self) -> None:
        def mutate(data: dict) -> None:
            data["architecture"]["semantic_layers"][0] = {}
            data["implementation_work_packages"][0]["id"] = {}
            data["retrieval_waves"][0]["id"] = []
            data["controlled_documents"][0]["required_terms"] = [{}]
            data["rules"]["allowed_redundancy"] = [{}]
            data["create_allowlist"] = [{}]
            data["create_permissions"][0]["allowed_paths"] = [{}]
            data["owners"][0]["owner_id"] = []
            data["owners"][0]["current_conflicts"][0]["disposition"] = {}
            data["owners"][1]["evidence_paths"] = [{}]
            data["owners"][2]["classification"] = []

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertNotIn("Traceback", completed.stderr)

    def test_malformed_candidate_values_fail_without_a_traceback(self) -> None:
        completed = self.run_candidate(
            {
                "schema_version": 1,
                "owner_id": [],
                "classification": "M",
                "candidate_path": {},
                "authority_symbol": [],
                "create_proof_task": {},
                "create_proof": CREATE_PROOF,
            }
        )

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("owner_id", completed.stderr)
        self.assertNotIn("Traceback", completed.stderr)

    def test_invalid_ledger_with_candidate_fails_without_a_traceback(self) -> None:
        with LEDGER.open("r", encoding="utf-8") as handle:
            ledger = json.load(handle)
        ledger["owners"] = None
        ledger["create_permissions"] = None
        candidate = {
            "schema_version": 1,
            "owner_id": "artifact.mesh",
            "classification": "M",
            "candidate_path": "BehavioralAISubstrate/Sources/BASRuntimeCore/BASArtifactMeshCore.swift",
            "authority_symbol": "BASArtifactStorePort",
            "create_proof_task": "contracts-layercell:Task 2",
            "create_proof": CREATE_PROOF,
        }

        completed = self.run_ledger_and_candidate(ledger, candidate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("owners must be a list", completed.stderr)
        self.assertIn("candidate semantic validation skipped", completed.stderr)
        self.assertNotIn("Traceback", completed.stderr)

    def test_all_architecture_and_domain_plans_are_controlled(self) -> None:
        def mutate(data: dict) -> None:
            data.pop("controlled_documents", None)

        completed = self.run_mutated_ledger(mutate)

        self.assertNotEqual(completed.returncode, 0)
        self.assertIn("controlled document set", completed.stderr)
        self.assertIn("seven", completed.stderr)


_ED25519_Q = 2**255 - 19
_ED25519_L = 2**252 + 27742317777372353535851937790883648493
_ED25519_D = -121665 * pow(121666, _ED25519_Q - 2, _ED25519_Q) % _ED25519_Q
_ED25519_I = pow(2, (_ED25519_Q - 1) // 4, _ED25519_Q)


def _ed25519_xrecover(y: int) -> int:
    xx = (y * y - 1) * pow(_ED25519_D * y * y + 1, _ED25519_Q - 2, _ED25519_Q)
    x = pow(xx, (_ED25519_Q + 3) // 8, _ED25519_Q)
    if (x * x - xx) % _ED25519_Q != 0:
        x = x * _ED25519_I % _ED25519_Q
    if x & 1:
        x = _ED25519_Q - x
    return x


_ED25519_B_Y = 4 * pow(5, _ED25519_Q - 2, _ED25519_Q) % _ED25519_Q
_ED25519_B = (_ed25519_xrecover(_ED25519_B_Y), _ED25519_B_Y)


def _ed25519_add(left: tuple[int, int], right: tuple[int, int]) -> tuple[int, int]:
    x1, y1 = left
    x2, y2 = right
    denominator_x = pow(
        1 + _ED25519_D * x1 * x2 * y1 * y2,
        _ED25519_Q - 2,
        _ED25519_Q,
    )
    denominator_y = pow(
        1 - _ED25519_D * x1 * x2 * y1 * y2,
        _ED25519_Q - 2,
        _ED25519_Q,
    )
    return (
        (x1 * y2 + x2 * y1) * denominator_x % _ED25519_Q,
        (y1 * y2 + x1 * x2) * denominator_y % _ED25519_Q,
    )


def _ed25519_multiply(point: tuple[int, int], scalar: int) -> tuple[int, int]:
    result = (0, 1)
    addend = point
    while scalar:
        if scalar & 1:
            result = _ed25519_add(result, addend)
        addend = _ed25519_add(addend, addend)
        scalar >>= 1
    return result


def _ed25519_encode(point: tuple[int, int]) -> bytes:
    x, y = point
    encoded = y | ((x & 1) << 255)
    return encoded.to_bytes(32, "little")


def _test_ed25519_key(seed: bytes) -> tuple[bytes, bytes, int]:
    digest = hashlib.sha512(seed).digest()
    scalar_bytes = bytearray(digest[:32])
    scalar_bytes[0] &= 248
    scalar_bytes[31] &= 63
    scalar_bytes[31] |= 64
    scalar = int.from_bytes(scalar_bytes, "little")
    public_key = _ed25519_encode(_ed25519_multiply(_ED25519_B, scalar))
    return public_key, digest[32:], scalar


def _test_ed25519_sign(seed: bytes, message: bytes) -> bytes:
    public_key, prefix, scalar = _test_ed25519_key(seed)
    nonce = int.from_bytes(hashlib.sha512(prefix + message).digest(), "little")
    nonce %= _ED25519_L
    encoded_r = _ed25519_encode(_ed25519_multiply(_ED25519_B, nonce))
    challenge = int.from_bytes(
        hashlib.sha512(encoded_r + public_key + message).digest(),
        "little",
    )
    challenge %= _ED25519_L
    encoded_s = ((nonce + challenge * scalar) % _ED25519_L).to_bytes(
        32,
        "little",
    )
    return encoded_r + encoded_s


def _canonical_test_json(value: object) -> bytes:
    if value is None:
        return b"null"
    if value is True:
        return b"true"
    if value is False:
        return b"false"
    if type(value) is int:
        if not -(2**53 - 1) <= value <= 2**53 - 1:
            raise ValueError("test JSON integer is outside the safe range")
        return str(value).encode("ascii")
    if isinstance(value, str):
        value.encode("utf-16-be")
        return json.dumps(
            value,
            ensure_ascii=False,
            allow_nan=False,
            separators=(",", ":"),
        ).encode("utf-8")
    if isinstance(value, list):
        return b"[" + b",".join(_canonical_test_json(item) for item in value) + b"]"
    if isinstance(value, dict):
        keys = sorted(value, key=lambda key: key.encode("utf-16-be"))
        return (
            b"{"
            + b",".join(
                _canonical_test_json(key) + b":" + _canonical_test_json(value[key])
                for key in keys
            )
            + b"}"
        )
    raise ValueError("unsupported test JSON value")


def _test_governance_signature_preimage(value: object) -> bytes:
    return hashlib.sha256(_canonical_test_json(value)).digest()


_TEST_ROLE_SCHEMA_SCOPES = (
    ("source-selector", "QinaoDualSpaceSourceSelectionV1"),
    ("root-admission-signer", "QinaoRootAdmissionReceiptV1"),
    ("design-edge-admission-signer", "QinaoDesignEdgeAdmissionReceiptV1"),
    ("wave-bundle-reviewer", "QinaoWaveCategoryEvidenceV1"),
    ("wave-bundle-reviewer", "QinaoWaveBundleV1"),
    ("wave-admission-signer", "QinaoWaveAdmissionReceiptV1"),
    ("k4-evidence-signer", "QinaoK4PhysicalDeviceProfileV1"),
    ("k4-evidence-signer", "QinaoK4IOS27PlatformSpikeV1"),
    ("runtime-chain-signer", "QinaoW6RuntimeReceiptChainV1"),
)

_AMENDMENT_2_APPROVED_DESIGN = {
    "path": (
        "docs/superpowers/specs/"
        "2026-07-29-qinao-dual-space-automation-apple-ecosystem-design.md"
    ),
    "commit": "c4e6cf23fd28d01abea3b9c5d8b282ba9dd9f271",
    "tree": "deef57197db409d6e4b33d5bfe9f7521eacefa12",
    "blob": "bbc586cb5787d872f8980f95a766f8afa90f9221",
    "byteLength": 113470,
    "sha256": "50338e28492cd8dc7a81f28a07a871d70f02020af56549cb1384b9431bd5fcf6",
}


def _test_scoped_trust_key(
    seed: bytes,
    key_id: str,
    role: str,
    schema_scope: str,
    *,
    principal_id: str | None = None,
    issued_at: str = "2026-07-29T00:00:00Z",
    expires_at: str = "2030-01-01T00:00:00Z",
) -> dict:
    public_key, _prefix, _scalar = _test_ed25519_key(seed)
    return {
        "keyID": key_id,
        "principalID": principal_id or key_id,
        "role": role,
        "schemaScope": schema_scope,
        "publicKey": base64.b64encode(public_key).decode("ascii"),
        "publicKeyFingerprintSHA256": hashlib.sha256(public_key).hexdigest(),
        "notBefore": issued_at,
        "notAfter": expires_at,
    }


def _test_complete_trust_keys(
    keys: list[dict],
    *,
    issued_at: str = "2026-07-29T00:00:00Z",
    expires_at: str = "2030-01-01T00:00:00Z",
) -> list[dict]:
    completed = copy.deepcopy(keys)
    present = {
        (row.get("role"), row.get("schemaScope"))
        for row in completed
        if isinstance(row, dict)
    }
    for role, schema_scope in _TEST_ROLE_SCHEMA_SCOPES:
        if (role, schema_scope) in present:
            continue
        seed = hashlib.sha256(
            f"test-only-filler:{role}:{schema_scope}".encode("utf-8")
        ).digest()
        completed.append(
            _test_scoped_trust_key(
                seed,
                f"test-only-filler-{hashlib.sha256(schema_scope.encode()).hexdigest()[:16]}",
                role,
                schema_scope,
                issued_at=issued_at,
                expires_at=expires_at,
            )
        )
    return sorted(completed, key=_canonical_test_json)


def _make_default_wave_arguments(directory: Path) -> list[str]:
    def git(*arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def signed(value: dict, seed: bytes) -> dict:
        result = copy.deepcopy(value)
        result["signature"] = base64.b64encode(
            _test_ed25519_sign(
                seed,
                _test_governance_signature_preimage(value),
            )
        ).decode("ascii")
        return result

    def write(name: str, value: object) -> Path:
        path = directory / name
        path.write_bytes(_canonical_test_json(value) + b"\n")
        return path

    base_tree = git("rev-parse", "HEAD^{tree}")
    source_public_key, _prefix, _scalar = _test_ed25519_key(
        QinaoWaveAuthorityGateTests.SOURCE_SELECTION_SEED
    )
    category_public_key, _prefix, _scalar = _test_ed25519_key(
        QinaoWaveAuthorityGateTests.CATEGORY_REVIEW_SEED
    )
    trust_root = {
        "schema": "QinaoAdmissionTrustRootV1",
        "repositoryIdentity": QinaoWaveAuthorityGateTests.REPOSITORY_IDENTITY,
        "issuedAt": QinaoWaveAuthorityGateTests.ISSUED_AT,
        "expiresAt": QinaoWaveAuthorityGateTests.EXPIRES_AT,
        "keys": _test_complete_trust_keys(
            [
                {
                    "keyID": QinaoWaveAuthorityGateTests.SOURCE_SELECTION_KEY_ID,
                    "principalID": (
                        QinaoWaveAuthorityGateTests.SOURCE_SELECTION_KEY_ID
                    ),
                    "role": "source-selector",
                    "schemaScope": "QinaoDualSpaceSourceSelectionV1",
                    "publicKey": base64.b64encode(source_public_key).decode("ascii"),
                    "publicKeyFingerprintSHA256": hashlib.sha256(
                        source_public_key
                    ).hexdigest(),
                    "notBefore": QinaoWaveAuthorityGateTests.ISSUED_AT,
                    "notAfter": QinaoWaveAuthorityGateTests.EXPIRES_AT,
                },
                {
                    "keyID": QinaoWaveAuthorityGateTests.CATEGORY_REVIEW_KEY_ID,
                    "principalID": (QinaoWaveAuthorityGateTests.CATEGORY_REVIEW_KEY_ID),
                    "role": "wave-bundle-reviewer",
                    "schemaScope": "QinaoWaveCategoryEvidenceV1",
                    "publicKey": base64.b64encode(category_public_key).decode("ascii"),
                    "publicKeyFingerprintSHA256": hashlib.sha256(
                        category_public_key
                    ).hexdigest(),
                    "notBefore": QinaoWaveAuthorityGateTests.ISSUED_AT,
                    "notAfter": QinaoWaveAuthorityGateTests.EXPIRES_AT,
                },
            ],
        ),
        "revokedNonces": [],
    }
    design_digest = _AMENDMENT_2_APPROVED_DESIGN["sha256"]
    selected_head = git("rev-parse", "HEAD")
    source_selection = signed(
        {
            "schemaVersion": 1,
            "repositoryIdentity": QinaoWaveAuthorityGateTests.REPOSITORY_IDENTITY,
            "selectedHEAD": selected_head,
            "selectedTree": base_tree,
            "approvedDesign": copy.deepcopy(_AMENDMENT_2_APPROVED_DESIGN),
            "candidateComparisons": [
                {
                    "candidateID": "selected-worktree",
                    "comparisonBaseHEAD": selected_head,
                    "head": selected_head,
                    "tree": base_tree,
                    "selected": True,
                    "committedRows": [],
                    "stagedRows": [],
                    "unstagedRows": [],
                    "untrackedRows": [],
                }
            ],
            "reviewerPrincipal": (QinaoWaveAuthorityGateTests.SOURCE_SELECTION_KEY_ID),
            "reviewerRole": "source-selector",
            "issuedAt": QinaoWaveAuthorityGateTests.ISSUED_AT,
            "expiresAt": QinaoWaveAuthorityGateTests.EXPIRES_AT,
            "nonce": "legacy-source-selection-test-nonce",
            "signatureAlgorithm": "Ed25519",
        },
        QinaoWaveAuthorityGateTests.SOURCE_SELECTION_SEED,
    )
    empty_diff_root = hashlib.sha256(_canonical_test_json([])).hexdigest()
    categories: dict[str, Path] = {}
    for category in ("create", "extension", "adapter", "fixture"):
        categories[category] = write(
            f"legacy-{category}.json",
            signed(
                {
                    "schema": "QinaoWaveCategoryEvidenceV1",
                    "repositoryIdentity": (
                        QinaoWaveAuthorityGateTests.REPOSITORY_IDENTITY
                    ),
                    "wave": "W0",
                    "waveSliceID": "w0.gates",
                    "sequenceOrdinal": 1,
                    "category": category,
                    "status": "notApplicable",
                    "baseTree": base_tree,
                    "approvedDesignBlob": design_digest,
                    "productionDiffRoot": empty_diff_root,
                    "reviewedRows": [],
                    "reviewedRowsRoot": empty_diff_root,
                    "anchors": [],
                    "reason": "legacy checker tests carry no production tree diff",
                    "issuedAt": QinaoWaveAuthorityGateTests.ISSUED_AT,
                    "expiresAt": QinaoWaveAuthorityGateTests.EXPIRES_AT,
                    "nonce": f"legacy-{category}-test-nonce",
                    "signer": QinaoWaveAuthorityGateTests.CATEGORY_REVIEW_KEY_ID,
                    "role": "wave-bundle-reviewer",
                    "signatureAlgorithm": "Ed25519",
                },
                QinaoWaveAuthorityGateTests.CATEGORY_REVIEW_SEED,
            ),
        )
    trust_path = write("legacy-trust-root.json", trust_root)
    selection_path = write("legacy-source-selection.json", source_selection)
    return [
        "--source-selection",
        str(selection_path),
        "--trust-root",
        str(trust_path),
        "--base-tree",
        base_tree,
        "--candidate-tree",
        base_tree,
        "--wave",
        "W0",
        "--wave-slice-id",
        "w0.gates",
        "--sequence-ordinal",
        "1",
        "--create-manifest-or-disposition",
        str(categories["create"]),
        "--extension-manifest-or-disposition",
        str(categories["extension"]),
        "--adapter-manifest-or-disposition",
        str(categories["adapter"]),
        "--fixture-set-or-disposition",
        str(categories["fixture"]),
    ]


class QinaoStrictEd25519AndTrustRootTests(unittest.TestCase):
    """Critical RED coverage for strict signature and role separation."""

    def test_termination_never_reaps_leader_before_final_group_kill(
        self,
    ) -> None:
        events: list[object] = []

        class Stream:
            def close(self) -> None:
                events.append("close")

        class Process:
            pid = 424_242
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
                checker,
                "killpg",
                side_effect=observe_killpg,
            ),
            mock.patch.object(
                checker,
                "waitid",
                create=True,
                return_value=object(),
            ),
            mock.patch.object(
                checker,
                "sleep",
                create=True,
            ),
        ):
            checker.terminate_process_group(Process(), grace_seconds=0.01)

        kill_index = events.index(("killpg", signal.SIGKILL))
        wait_index = next(
            index
            for index, event in enumerate(events)
            if isinstance(event, tuple) and event[0] == "wait"
        )
        self.assertLess(kill_index, wait_index, events)

    def test_bounded_subprocess_kills_pipe_holding_descendants(self) -> None:
        if not hasattr(os, "fork") or not hasattr(os, "killpg"):
            self.skipTest("process-group descendant test requires POSIX fork/killpg")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tool = root / "git"
            parent_pid_path = root / "hanging-owner-parent.pid"
            child_pid_path = root / "hanging-owner-child.pid"
            tool.write_text(
                f"""#!{sys.executable}
import os
from pathlib import Path
import signal
import time
parent_path = Path(os.environ["HANGING_PARENT_PID"])
child_path = Path(os.environ["HANGING_CHILD_PID"])
parent_path.write_text(str(os.getpid()), encoding="ascii")
child = os.fork()
if child == 0:
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    child_path.write_text(str(os.getpid()), encoding="ascii")
    while True:
        print("pipe held", flush=True)
        time.sleep(0.02)
while True:
    time.sleep(0.02)
""",
                encoding="utf-8",
            )
            tool.chmod(0o755)
            environment = {
                "PATH": str(root),
                "HANGING_PARENT_PID": str(parent_pid_path),
                "HANGING_CHILD_PID": str(child_pid_path),
            }

            def force_cleanup() -> None:
                if not parent_pid_path.exists():
                    return
                try:
                    os.killpg(
                        int(parent_pid_path.read_text(encoding="ascii")),
                        signal.SIGKILL,
                    )
                except (ProcessLookupError, PermissionError, ValueError):
                    pass

            self.addCleanup(force_cleanup)
            started = time.monotonic()
            real_popen = subprocess.Popen

            def launch_hanging_process(_command, **kwargs):
                kwargs["env"] = environment
                return real_popen([sys.executable, str(tool)], **kwargs)

            with mock.patch.object(
                checker.subprocess,
                "Popen",
                side_effect=launch_hanging_process,
            ):
                with self.assertRaises(subprocess.TimeoutExpired):
                    checker.run_bounded_process(
                        ["git", "cat-file", "-t", "a" * 7],
                        cwd=root,
                        timeout_seconds=1.0,
                        termination_grace_seconds=0.10,
                        stdout_limit_bytes=1024,
                        stderr_limit_bytes=1024,
                        text=True,
                    )
            self.assertLess(time.monotonic() - started, 3.0)
            self.assertTrue(child_pid_path.is_file())
            child_pid = int(child_pid_path.read_text(encoding="ascii"))
            self.assertTrue(
                _wait_for_pid_exit(child_pid),
                "descendant remained after timeout",
            )

    def test_rfc8032_ed25519_vector_verifies(self) -> None:
        public_key = bytes.fromhex(
            "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
        )
        signature = bytes.fromhex(
            "e5564300c360ac729086e2cc806e828a"
            "84877f1eb8e5d974d873e06522490155"
            "5fb8821590a33bacc61e39701cf9b46b"
            "d25bf5f0595bbe24655141438e7a100b"
        )

        self.assertTrue(checker.verify_ed25519_signature(public_key, b"", signature))

    def test_tree_object_cannot_masquerade_as_selected_commit(self) -> None:
        tree = subprocess.run(
            ["git", "rev-parse", "HEAD^{tree}"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

        self.assertIsNone(checker.git_commit_tree(ROOT, tree))

    def test_git_object_checks_ignore_attacker_controlled_environment(self) -> None:
        commit = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        expected_tree = subprocess.run(
            ["git", "rev-parse", "HEAD^{tree}"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        poison = {
            "GIT_ALTERNATE_OBJECT_DIRECTORIES": str(ROOT / "attacker-objects"),
            "GIT_DIR": str(ROOT / "attacker.git"),
            "GIT_INDEX_FILE": str(ROOT / "attacker-index"),
            "GIT_OBJECT_DIRECTORY": str(ROOT / "attacker-object-dir"),
            "GIT_WORK_TREE": str(ROOT / "attacker-worktree"),
        }

        with mock.patch.dict(os.environ, poison, clear=False):
            actual_tree = checker.git_commit_tree(ROOT, commit)

        self.assertEqual(actual_tree, expected_tree)

    def test_git_object_checks_fail_closed_on_timeout(self) -> None:
        with mock.patch.object(
            checker,
            "run_bounded_process",
            side_effect=subprocess.TimeoutExpired(["git"], 30),
        ):
            self.assertIsNone(checker.git_commit_tree(ROOT, "a" * 40))
            self.assertFalse(checker.git_tree_exists(ROOT, "a" * 40))

    def test_identity_public_key_forgery_is_rejected(self) -> None:
        identity_public_key = b"\x01" + (b"\0" * 31)
        encoded_basepoint = _ed25519_encode(_ED25519_B)
        forged_signature = encoded_basepoint + (1).to_bytes(32, "little")

        self.assertFalse(
            checker.verify_ed25519_signature(
                identity_public_key,
                b"arbitrary attacker-selected message",
                forged_signature,
            )
        )

    def test_identity_point_is_not_a_valid_public_key_or_signature_point(self) -> None:
        identity = b"\x01" + (b"\0" * 31)

        with self.assertRaisesRegex(ValueError, "identity|small-order|subgroup"):
            checker.ed25519_decode_point(identity)

    def test_small_order_and_noncanonical_points_and_scalar_are_rejected(
        self,
    ) -> None:
        order_two = (_ED25519_Q - 1).to_bytes(32, "little")
        noncanonical_y = _ED25519_Q.to_bytes(32, "little")
        public_key, _prefix, _scalar = _test_ed25519_key(bytes(range(32)))
        encoded_basepoint = _ed25519_encode(_ED25519_B)

        with self.assertRaises(ValueError):
            checker.ed25519_decode_point(order_two)
        with self.assertRaises(ValueError):
            checker.ed25519_decode_point(noncanonical_y)
        self.assertFalse(
            checker.verify_ed25519_signature(
                public_key,
                b"strict scalar boundary",
                encoded_basepoint + _ED25519_L.to_bytes(32, "little"),
            )
        )

    @staticmethod
    def trust_root(keys: list[dict]) -> dict:
        keys = _test_complete_trust_keys(keys)
        return {
            "schema": "QinaoAdmissionTrustRootV1",
            "repositoryIdentity": "qinao/test-strict-trust-root",
            "issuedAt": "2026-07-29T00:00:00Z",
            "expiresAt": "2030-01-01T00:00:00Z",
            "keys": keys,
            "revokedNonces": [],
        }

    @staticmethod
    def trust_key(
        seed: bytes,
        key_id: str,
        role: str,
        schema_scope: str | None = None,
        principal_id: str | None = None,
    ) -> dict:
        default_scopes = {
            "source-selector": "QinaoDualSpaceSourceSelectionV1",
            "root-admission-signer": "QinaoRootAdmissionReceiptV1",
            ("design-edge-admission-signer"): "QinaoDesignEdgeAdmissionReceiptV1",
            "wave-bundle-reviewer": "QinaoWaveCategoryEvidenceV1",
            "wave-admission-signer": "QinaoWaveAdmissionReceiptV1",
            "k4-evidence-signer": "QinaoK4PhysicalDeviceProfileV1",
            "runtime-chain-signer": "QinaoW6RuntimeReceiptChainV1",
        }
        return _test_scoped_trust_key(
            seed,
            key_id,
            role,
            schema_scope or default_scopes.get(role, "invalid"),
            principal_id=principal_id,
        )

    def test_public_key_fingerprint_cannot_cross_roles(self) -> None:
        source_key = self.trust_key(
            b"\x11" * 32,
            "source-key",
            "source-selector",
        )
        reused_key = dict(source_key)
        reused_key["keyID"] = "root-key-alias"
        reused_key["role"] = "root-admission-signer"

        errors = checker.validate_trust_root(
            self.trust_root([source_key, reused_key]),
            verification_time=VERIFICATION_TIME,
        )

        self.assertTrue(
            any(
                "fingerprint" in error and "role/schemaScope" in error
                for error in errors
            ),
            errors,
        )

    def test_only_the_seven_frozen_role_families_are_accepted(self) -> None:
        for invented_role in (
            "wave-category-reviewer",
            "k4-device-profile-signer",
        ):
            with self.subTest(role=invented_role):
                errors = checker.validate_trust_root(
                    self.trust_root(
                        [
                            self.trust_key(
                                b"\x22" * 32,
                                "invented-role-key",
                                invented_role,
                            )
                        ]
                    ),
                    verification_time=VERIFICATION_TIME,
                )
                self.assertTrue(
                    any("role" in error and "frozen" in error for error in errors),
                    errors,
                )

    def test_distinct_schema_keys_may_share_one_frozen_role_family(self) -> None:
        errors = checker.validate_trust_root(
            self.trust_root(
                [
                    self.trust_key(
                        b"\x33" * 32,
                        "bundle-category-key",
                        "wave-bundle-reviewer",
                        "QinaoWaveCategoryEvidenceV1",
                    ),
                    self.trust_key(
                        b"\x44" * 32,
                        "bundle-envelope-key",
                        "wave-bundle-reviewer",
                        "QinaoWaveBundleV1",
                    ),
                ]
            ),
            verification_time=VERIFICATION_TIME,
        )

        self.assertEqual(errors, [])

    def test_future_issued_trust_root_and_signed_document_are_rejected(
        self,
    ) -> None:
        seed = b"\x45" * 32
        key_id = "future-issued-root-key"
        trust_root = self.trust_root(
            [self.trust_key(seed, key_id, "root-admission-signer")]
        )
        future_root = copy.deepcopy(trust_root)
        future_root["issuedAt"] = "2099-01-01T00:00:00Z"
        future_root["expiresAt"] = "2100-01-01T00:00:00Z"
        unsigned = {
            "schema": "QinaoRootAdmissionReceiptV1",
            "repositoryIdentity": trust_root["repositoryIdentity"],
            "issuedAt": "2099-01-01T00:00:00Z",
            "expiresAt": "2100-01-01T00:00:00Z",
            "nonce": "test-only-future-issued-document",
            "signer": key_id,
            "role": "root-admission-signer",
            "signatureAlgorithm": "Ed25519",
        }
        document = {
            **unsigned,
            "signature": base64.b64encode(
                _test_ed25519_sign(
                    seed,
                    _test_governance_signature_preimage(unsigned),
                )
            ).decode("ascii"),
        }

        root_errors = checker.validate_trust_root(
            future_root,
            verification_time=VERIFICATION_TIME,
        )
        document_errors = checker.validate_signed_document(
            document,
            trust_root,
            expected_role="root-admission-signer",
            label="future-issued document",
            expected_schema_scope="QinaoRootAdmissionReceiptV1",
            verification_time=VERIFICATION_TIME,
        )

        self.assertTrue(
            any("issuedAt" in error and "future" in error for error in root_errors),
            root_errors,
        )
        self.assertTrue(
            any("issuedAt" in error and "future" in error for error in document_errors),
            document_errors,
        )

    def test_rfc8785_utf16_property_order_is_canonical(self) -> None:
        value = {
            "\u20ac": "Euro Sign",
            "\r": "Carriage Return",
            "\ufb33": "Hebrew Letter Dalet With Dagesh",
            "1": "One",
            "\U0001f600": "Emoji: Grinning Face",
            "\u0080": "Control",
            "\u00f6": "Latin Small Letter O With Diaeresis",
        }
        expected = (
            '{"\\r":"Carriage Return","1":"One",'
            '"\u0080":"Control","\u00f6":"Latin Small Letter O With Diaeresis",'
            '"\u20ac":"Euro Sign","\U0001f600":"Emoji: Grinning Face",'
            '"\ufb33":"Hebrew Letter Dalet With Dagesh"}'
        ).encode("utf-8")

        self.assertEqual(checker.canonical_json_bytes(value), expected)

    def test_signed_document_uses_sha256_of_rfc8785_bytes_not_raw_json(
        self,
    ) -> None:
        seed = b"\x54" * 32
        key_id = "digest-preimage-root-key"
        trust_root = self.trust_root(
            [self.trust_key(seed, key_id, "root-admission-signer")]
        )
        unsigned = {
            "schema": "QinaoRootAdmissionReceiptV1",
            "repositoryIdentity": trust_root["repositoryIdentity"],
            "issuedAt": "2026-07-29T00:00:00Z",
            "expiresAt": "2030-01-01T00:00:00Z",
            "nonce": "test-only-rfc8785-sha256-preimage",
            "signer": key_id,
            "role": "root-admission-signer",
            "signatureAlgorithm": "Ed25519",
            "payload": {"\U0001f600": 2, "\uffff": 1},
        }
        canonical = checker.canonical_json_bytes(unsigned)
        digest_signed = {
            **unsigned,
            "signature": base64.b64encode(
                _test_ed25519_sign(
                    seed,
                    hashlib.sha256(canonical).digest(),
                )
            ).decode("ascii"),
        }
        raw_signed = {
            **unsigned,
            "signature": base64.b64encode(_test_ed25519_sign(seed, canonical)).decode(
                "ascii"
            ),
        }

        self.assertEqual(
            checker.validate_signed_document(
                digest_signed,
                trust_root,
                expected_role="root-admission-signer",
                label="digest preimage",
                expected_schema_scope="QinaoRootAdmissionReceiptV1",
                verification_time=VERIFICATION_TIME,
            ),
            [],
        )
        raw_errors = checker.validate_signed_document(
            raw_signed,
            trust_root,
            expected_role="root-admission-signer",
            label="raw preimage",
            expected_schema_scope="QinaoRootAdmissionReceiptV1",
            verification_time=VERIFICATION_TIME,
        )
        self.assertTrue(
            any("signature is invalid" in error for error in raw_errors),
            raw_errors,
        )

    def test_exact_task0_source_selection_schema_is_accepted(self) -> None:
        seed = b"\x55" * 32
        key_id = "independent-source-selector"
        selected_head = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        selected_tree = subprocess.run(
            ["git", "rev-parse", "HEAD^{tree}"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        trust_root = self.trust_root([self.trust_key(seed, key_id, "source-selector")])
        unsigned_selection = {
            "schemaVersion": 1,
            "repositoryIdentity": trust_root["repositoryIdentity"],
            "selectedHEAD": selected_head,
            "selectedTree": selected_tree,
            "approvedDesign": {
                "path": (
                    "docs/superpowers/specs/"
                    "2026-07-29-qinao-dual-space-automation-"
                    "apple-ecosystem-design.md"
                ),
                "commit": "c4e6cf23fd28d01abea3b9c5d8b282ba9dd9f271",
                "tree": "deef57197db409d6e4b33d5bfe9f7521eacefa12",
                "blob": "bbc586cb5787d872f8980f95a766f8afa90f9221",
                "byteLength": 113470,
                "sha256": (
                    "50338e28492cd8dc7a81f28a07a871d70f02020af56549cb1384b9431bd5fcf6"
                ),
            },
            "candidateComparisons": [
                {
                    "candidateID": "selected-worktree",
                    "comparisonBaseHEAD": selected_head,
                    "head": selected_head,
                    "tree": selected_tree,
                    "selected": True,
                    "committedRows": [],
                    "stagedRows": [],
                    "unstagedRows": [],
                    "untrackedRows": [],
                }
            ],
            "reviewerPrincipal": key_id,
            "reviewerRole": "source-selector",
            "issuedAt": "2026-07-29T00:00:00Z",
            "expiresAt": "2030-01-01T00:00:00Z",
            "nonce": "task0-exact-selection-test",
            "signatureAlgorithm": "Ed25519",
        }
        selection = dict(unsigned_selection)
        selection["signature"] = base64.b64encode(
            _test_ed25519_sign(
                seed,
                _test_governance_signature_preimage(unsigned_selection),
            )
        ).decode("ascii")

        errors = checker.validate_source_selection(
            selection,
            trust_root,
            root=ROOT,
            verification_time=VERIFICATION_TIME,
        )

        self.assertEqual(errors, [])


class QinaoWaveAuthorityGateTests(unittest.TestCase):
    """Task 1 RED/GREEN coverage for the candidate-tree authority gate."""

    REPOSITORY_IDENTITY = "qinao/project06"
    DESIGN_PATH = (
        ROOT
        / "docs"
        / "superpowers"
        / "specs"
        / "2026-07-29-qinao-dual-space-automation-apple-ecosystem-design.md"
    )
    SOURCE_SELECTION_SEED = bytes(range(32))
    CATEGORY_REVIEW_SEED = bytes(reversed(range(32)))
    SOURCE_SELECTION_KEY_ID = "test-source-selection-key"
    CATEGORY_REVIEW_KEY_ID = "test-category-review-key"
    ISSUED_AT = "2026-07-29T00:00:00Z"
    EXPIRES_AT = "2030-01-01T00:00:00Z"

    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_directory.cleanup)
        self.directory = Path(self.temp_directory.name)
        self.root = self.directory / "repository"
        self.root.mkdir()
        subprocess.run(
            ["git", "init", "-q"],
            cwd=self.root,
            check=True,
        )
        real_git_common = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        real_git_common_path = Path(real_git_common)
        if not real_git_common_path.is_absolute():
            real_git_common_path = (ROOT / real_git_common_path).resolve()
        self.real_object_directory = real_git_common_path / "objects"
        self.temporary_object_directory = self.root / ".git/objects"
        alternates = self.temporary_object_directory / "info/alternates"
        alternates.parent.mkdir(parents=True, exist_ok=True)
        alternates.write_text(
            f"{self.real_object_directory}\n",
            encoding="utf-8",
        )
        self.git_environment = _isolated_git_environment(
            os.environ,
            object_directory=self.temporary_object_directory,
            alternate_object_directory=self.real_object_directory,
        )
        self.base_commit = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.git("symbolic-ref", "HEAD", "refs/heads/qinao-test-base")
        self.git(
            "update-ref",
            "refs/heads/qinao-test-base",
            self.base_commit,
        )
        self.base_tree = self.git("rev-parse", "HEAD^{tree}")
        self.candidate_tree = self.base_tree
        self.design_digest = _AMENDMENT_2_APPROVED_DESIGN["sha256"]
        self.empty_diff_root = hashlib.sha256(_canonical_test_json([])).hexdigest()
        source_public_key, _prefix, _scalar = _test_ed25519_key(
            self.SOURCE_SELECTION_SEED
        )
        category_public_key, _prefix, _scalar = _test_ed25519_key(
            self.CATEGORY_REVIEW_SEED
        )
        self.trust_root = {
            "schema": "QinaoAdmissionTrustRootV1",
            "repositoryIdentity": self.REPOSITORY_IDENTITY,
            "issuedAt": self.ISSUED_AT,
            "expiresAt": self.EXPIRES_AT,
            "keys": _test_complete_trust_keys(
                [
                    {
                        "keyID": self.CATEGORY_REVIEW_KEY_ID,
                        "principalID": self.CATEGORY_REVIEW_KEY_ID,
                        "role": "wave-bundle-reviewer",
                        "schemaScope": "QinaoWaveCategoryEvidenceV1",
                        "publicKey": base64.b64encode(category_public_key).decode(
                            "ascii"
                        ),
                        "publicKeyFingerprintSHA256": hashlib.sha256(
                            category_public_key
                        ).hexdigest(),
                        "notBefore": self.ISSUED_AT,
                        "notAfter": self.EXPIRES_AT,
                    },
                    {
                        "keyID": self.SOURCE_SELECTION_KEY_ID,
                        "principalID": self.SOURCE_SELECTION_KEY_ID,
                        "role": "source-selector",
                        "schemaScope": "QinaoDualSpaceSourceSelectionV1",
                        "publicKey": base64.b64encode(source_public_key).decode(
                            "ascii"
                        ),
                        "publicKeyFingerprintSHA256": hashlib.sha256(
                            source_public_key
                        ).hexdigest(),
                        "notBefore": self.ISSUED_AT,
                        "notAfter": self.EXPIRES_AT,
                    },
                ],
            ),
            "revokedNonces": [],
        }
        self.source_selection = self.signed(
            {
                "schemaVersion": 1,
                "repositoryIdentity": self.REPOSITORY_IDENTITY,
                "selectedHEAD": self.base_commit,
                "selectedTree": self.base_tree,
                "approvedDesign": copy.deepcopy(_AMENDMENT_2_APPROVED_DESIGN),
                "candidateComparisons": [
                    {
                        "candidateID": "selected-worktree",
                        "comparisonBaseHEAD": self.base_commit,
                        "head": self.base_commit,
                        "tree": self.base_tree,
                        "selected": True,
                        "committedRows": [],
                        "stagedRows": [],
                        "unstagedRows": [],
                        "untrackedRows": [],
                    }
                ],
                "reviewerPrincipal": self.SOURCE_SELECTION_KEY_ID,
                "reviewerRole": "source-selector",
                "issuedAt": self.ISSUED_AT,
                "expiresAt": self.EXPIRES_AT,
                "nonce": "source-selection-test-nonce",
                "signatureAlgorithm": "Ed25519",
            },
            seed=self.SOURCE_SELECTION_SEED,
        )
        self.documents: dict[str, dict] = {
            category: self.category_document(category)
            for category in ("create", "extension", "adapter", "fixture")
        }

    def test_temporary_git_environment_drops_repository_locator_overrides(
        self,
    ) -> None:
        poisoned = {
            "HOME": "/test-only/home",
            "GIT_DIR": "/attacker/repository.git",
            "GIT_WORK_TREE": "/attacker/worktree",
            "GIT_INDEX_FILE": "/attacker/index",
            "GIT_COMMON_DIR": "/attacker/common",
            "GIT_CEILING_DIRECTORIES": "/attacker/ceiling",
            "GIT_OBJECT_DIRECTORY": "/attacker/objects",
            "GIT_ALTERNATE_OBJECT_DIRECTORIES": "/attacker/alternates",
        }

        isolated = _isolated_git_environment(
            poisoned,
            object_directory=self.temporary_object_directory,
            alternate_object_directory=self.real_object_directory,
        )

        self.assertEqual(isolated["HOME"], "/test-only/home")
        for name in (
            "GIT_DIR",
            "GIT_WORK_TREE",
            "GIT_INDEX_FILE",
            "GIT_COMMON_DIR",
            "GIT_CEILING_DIRECTORIES",
        ):
            self.assertNotIn(name, isolated)
        self.assertEqual(
            isolated["GIT_OBJECT_DIRECTORY"],
            str(self.temporary_object_directory),
        )
        self.assertEqual(
            isolated["GIT_ALTERNATE_OBJECT_DIRECTORIES"],
            str(self.real_object_directory),
        )

    def git(self, *arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            env=self.git_environment,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def assert_temporary_object(self, object_id: str) -> None:
        object_path = self.temporary_object_directory / object_id[:2] / object_id[2:]
        self.assertTrue(
            object_path.is_file(),
            f"new Git object escaped the temporary object DB: {object_id}",
        )

    def signed(self, value: dict, *, seed: bytes | None = None) -> dict:
        signed = copy.deepcopy(value)
        signed["signature"] = base64.b64encode(
            _test_ed25519_sign(
                self.CATEGORY_REVIEW_SEED if seed is None else seed,
                _test_governance_signature_preimage(value),
            )
        ).decode("ascii")
        return signed

    def category_document(
        self,
        category: str,
        *,
        status: str = "notApplicable",
        rows: list[dict] | None = None,
        anchors: list[object] | None = None,
    ) -> dict:
        rows = [] if rows is None else rows
        return self.signed(
            {
                "schema": "QinaoWaveCategoryEvidenceV1",
                "repositoryIdentity": self.REPOSITORY_IDENTITY,
                "wave": "W0",
                "waveSliceID": "w0.gates",
                "sequenceOrdinal": 1,
                "category": category,
                "status": status,
                "baseTree": self.base_tree,
                "approvedDesignBlob": self.design_digest,
                "productionDiffRoot": self.empty_diff_root,
                "reviewedRows": rows,
                "reviewedRowsRoot": hashlib.sha256(
                    _canonical_test_json(sorted(rows, key=_canonical_test_json))
                ).hexdigest(),
                "anchors": [] if anchors is None else anchors,
                "reason": (
                    "W0 changes governance and floor tooling only"
                    if status == "notApplicable"
                    else ""
                ),
                "issuedAt": self.ISSUED_AT,
                "expiresAt": self.EXPIRES_AT,
                "nonce": f"{category}-test-nonce",
                "signer": self.CATEGORY_REVIEW_KEY_ID,
                "role": "wave-bundle-reviewer",
                "signatureAlgorithm": "Ed25519",
            }
        )

    def write_json(self, name: str, value: object) -> Path:
        path = self.directory / name
        path.write_bytes(_canonical_test_json(value) + b"\n")
        return path

    def command(self) -> list[str]:
        paths = {
            "trust-root": self.write_json("trust-root.json", self.trust_root),
            "source-selection": self.write_json(
                "source-selection.json",
                self.source_selection,
            ),
        }
        for category, value in self.documents.items():
            paths[category] = self.write_json(f"{category}.json", value)
        return [
            sys.executable,
            str(SCRIPT),
            "--root",
            str(self.root),
            "--ledger",
            str(LEDGER),
            "--source-selection",
            str(paths["source-selection"]),
            "--trust-root",
            str(paths["trust-root"]),
            "--base-tree",
            self.base_tree,
            "--candidate-tree",
            self.candidate_tree,
            "--wave",
            "W0",
            "--wave-slice-id",
            "w0.gates",
            "--sequence-ordinal",
            "1",
            "--create-manifest-or-disposition",
            str(paths["create"]),
            "--extension-manifest-or-disposition",
            str(paths["extension"]),
            "--adapter-manifest-or-disposition",
            str(paths["adapter"]),
            "--fixture-set-or-disposition",
            str(paths["fixture"]),
        ]

    def run_gate(
        self, command: list[str] | None = None
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            self.command() if command is None else command,
            cwd=self.root,
            capture_output=True,
            text=True,
            check=False,
        )

    def mutate_document(self, category: str, mutation: Callable[[dict], None]) -> None:
        document = copy.deepcopy(self.documents[category])
        document.pop("signature")
        mutation(document)
        self.documents[category] = self.signed(document)

    def mutate_source_selection(self, mutation: Callable[[dict], None]) -> None:
        document = copy.deepcopy(self.source_selection)
        document.pop("signature")
        mutation(document)
        self.source_selection = self.signed(
            document,
            seed=self.SOURCE_SELECTION_SEED,
        )

    def source_selection_errors(self) -> list[str]:
        return checker.validate_source_selection(
            self.source_selection,
            self.trust_root,
            root=self.root,
            verification_time=VERIFICATION_TIME,
        )

    def candidate_tree_with_blob(self, path: str, contents: bytes) -> str:
        object_id = (
            subprocess.run(
                ["git", "hash-object", "-w", "--stdin"],
                cwd=self.root,
                env=self.git_environment,
                input=contents,
                check=True,
                capture_output=True,
            )
            .stdout.decode("ascii")
            .strip()
        )
        self.assert_temporary_object(object_id)
        index = self.directory / "index"
        environment = dict(self.git_environment)
        environment["GIT_INDEX_FILE"] = str(index)
        subprocess.run(
            ["git", "read-tree", self.base_tree],
            cwd=self.root,
            env=environment,
            check=True,
        )
        subprocess.run(
            [
                "git",
                "update-index",
                "--add",
                "--cacheinfo",
                f"100644,{object_id},{path}",
            ],
            cwd=self.root,
            env=environment,
            check=True,
        )
        tree = subprocess.run(
            ["git", "write-tree"],
            cwd=self.root,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assert_temporary_object(tree)
        return tree

    def candidate_tree_with_entry(
        self,
        path: str,
        contents: bytes,
        *,
        mode: str,
    ) -> tuple[str, str]:
        object_id = (
            subprocess.run(
                ["git", "hash-object", "-w", "--stdin"],
                cwd=self.root,
                env=self.git_environment,
                input=contents,
                check=True,
                capture_output=True,
            )
            .stdout.decode("ascii")
            .strip()
        )
        self.assert_temporary_object(object_id)
        tree = self.candidate_tree_with_object(
            path,
            object_id,
            mode=mode,
        )
        return tree, object_id

    def candidate_tree_with_object(
        self,
        path: str,
        object_id: str,
        *,
        mode: str,
    ) -> str:
        index = self.directory / f"index-{hashlib.sha256(path.encode()).hexdigest()}"
        environment = dict(self.git_environment)
        environment["GIT_INDEX_FILE"] = str(index)
        subprocess.run(
            ["git", "read-tree", self.base_tree],
            cwd=self.root,
            env=environment,
            check=True,
        )
        subprocess.run(
            [
                "git",
                "update-index",
                "--add",
                "--cacheinfo",
                f"{mode},{object_id},{path}",
            ],
            cwd=self.root,
            env=environment,
            check=True,
        )
        tree = subprocess.run(
            ["git", "write-tree"],
            cwd=self.root,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assert_temporary_object(tree)
        return tree

    def candidate_commit(self, tree: str) -> str:
        environment = dict(self.git_environment)
        environment.update(
            {
                "GIT_AUTHOR_NAME": "Qinao Test",
                "GIT_AUTHOR_EMAIL": "qinao-test@example.invalid",
                "GIT_AUTHOR_DATE": "2026-07-29T00:00:00Z",
                "GIT_COMMITTER_NAME": "Qinao Test",
                "GIT_COMMITTER_EMAIL": "qinao-test@example.invalid",
                "GIT_COMMITTER_DATE": "2026-07-29T00:00:00Z",
            }
        )
        commit = subprocess.run(
            [
                "git",
                "commit-tree",
                tree,
                "-p",
                self.git("rev-parse", "HEAD"),
                "-m",
                "test-only candidate",
            ],
            cwd=self.root,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assert_temporary_object(commit)
        return commit

    def test_candidate_git_objects_are_written_only_to_temporary_object_db(
        self,
    ) -> None:
        tree, blob = self.candidate_tree_with_entry(
            "SampleHost/TestOnlyCandidateObjectIsolation/value.txt",
            b"unique candidate object isolation bytes\n",
            mode="100644",
        )
        commit = self.candidate_commit(tree)

        self.assertNotEqual(
            self.temporary_object_directory.resolve(),
            self.real_object_directory.resolve(),
        )
        self.assertEqual(
            self.git_environment["GIT_OBJECT_DIRECTORY"],
            str(self.temporary_object_directory),
        )
        self.assertEqual(
            self.git_environment["GIT_ALTERNATE_OBJECT_DIRECTORIES"],
            str(self.real_object_directory),
        )
        for object_id in (blob, tree, commit):
            self.assert_temporary_object(object_id)

    def test_extensionless_authority_symlink_tree_row_fails_closed(
        self,
    ) -> None:
        paths = (
            "FourthPackage/Sources/DirectoryLink",
            "BehavioralAISubstrate/DeviceTestApp/Sources/DirectoryLink",
            "FourthPackage/Sources/Vendor/DirectoryLink",
            "FourthPackage/Sources/.build/DirectoryLink",
            "BehavioralAISubstrate/Cargo/layercore/src/GeneratedLink",
        )
        ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
        for path in paths:
            with self.subTest(path=path):
                candidate_tree, _blob = self.candidate_tree_with_entry(
                    path,
                    b"../Elsewhere",
                    mode="120000",
                )
                diff_rows, diff_errors = checker.git_tree_diff(
                    self.root,
                    self.base_tree,
                    candidate_tree,
                )
                self.assertEqual(diff_errors, [])
                self.assertEqual(
                    next(row["newMode"] for row in diff_rows if row["path"] == path),
                    "120000",
                )

                _categorized, errors = checker.derive_authority_rows(
                    diff_rows,
                    ledger,
                )

                self.assertTrue(
                    any(
                        path in error
                        and "authority namespace" in error
                        and "regular tracked file" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_regular_authority_entries_across_supported_topologies_are_governed(
        self,
    ) -> None:
        cases = (
            (
                "BehavioralAISubstrate/DeviceTestApp/Sources/BASStateCommitStore.swift",
                "100644",
                "extension",
            ),
            (
                "BehavioralAISubstrate/Cargo/layercore/src/authority.rs",
                "100755",
                "extension",
            ),
            (
                "BehavioralAISubstrate/Cargo/layercore/tests/integration.rs",
                "100644",
                "fixture",
            ),
            (
                "BehavioralAISubstrate/Cargo/layercore/benches/throughput",
                "100755",
                "fixture",
            ),
            (
                "FourthPackage/Sources/ExtensionlessAuthority",
                "100644",
                "extension",
            ),
            (
                "QinaoRuntimeSDK/Sources/Vendor/authority.cpp",
                "100644",
                "extension",
            ),
            (
                "QinaoRuntimeSDK/Sources/.build/authority.metal",
                "100644",
                "extension",
            ),
            (
                "BehavioralAISubstrate/DeviceTestApp/Resources/model.bin",
                "100644",
                "extension",
            ),
            (
                "BehavioralAISubstrate/Plugins/BuildTool/plugin.swift",
                "100644",
                "extension",
            ),
            (
                "BehavioralAISubstrate/Vendor/Runtime/runtime.h",
                "100644",
                "extension",
            ),
            (
                "SampleHost/Resources/Info.plist",
                "100644",
                "extension",
            ),
            (
                "BehavioralAISubstrate/DeviceTestApp/"
                "BASDeviceTest.xcodeproj/project.xcworkspace/"
                "contents.xcworkspacedata",
                "100644",
                "extension",
            ),
            (
                "BehavioralAISubstrate/DeviceTestApp/"
                "BASDeviceTest.xcodeproj/xcshareddata/xcschemes/"
                "BASDeviceTestApp.xcscheme",
                "100644",
                "extension",
            ),
        )
        ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
        for path, mode, expected_category in cases:
            with self.subTest(path=path, mode=mode):
                candidate_tree, _object_id = self.candidate_tree_with_entry(
                    path,
                    b"test-only governed authority entry\n",
                    mode=mode,
                )
                diff_rows, diff_errors = checker.git_tree_diff(
                    self.root,
                    self.base_tree,
                    candidate_tree,
                )
                self.assertEqual(diff_errors, [])

                categorized, errors = checker.derive_authority_rows(
                    diff_rows,
                    ledger,
                )

                governed_rows = [
                    row
                    for rows in categorized.values()
                    for row in rows
                    if row["path"] == path
                ]
                self.assertEqual(len(governed_rows), 1, (categorized, errors))
                self.assertEqual(
                    categorized[expected_category][0]["path"],
                    path,
                )
                if expected_category == "extension":
                    self.assertTrue(
                        any("unknown or ambiguous owner" in error for error in errors),
                        errors,
                    )
                else:
                    self.assertEqual(errors, [])

    def test_vendor_swiftpm_source_anchor_locks_production_kind_and_rows(
        self,
    ) -> None:
        paths = (
            "BehavioralAISubstrate/Vendor/swift-transformers/"
            "Sources/Tokenizers/Tests/Evil.swift",
            "BehavioralAISubstrate/Vendor/swift-transformers/"
            "Sources/Tokenizers/Fixtures/Evil.swift",
            "BehavioralAISubstrate/Vendor/swift-transformers/"
            "Sources/Tokenizers/DerivedData/Evil.swift",
            "BehavioralAISubstrate/Vendor/swift-transformers/"
            "Sources/Tokenizers/.build/Evil.swift",
            "BehavioralAISubstrate/Vendor/swift-transformers/"
            "Sources/Tokenizers/cache.tmp",
        )
        ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
        for path in paths:
            with self.subTest(path=path):
                candidate_tree, _object_id = self.candidate_tree_with_entry(
                    path,
                    b"test-only nested vendor production entry\n",
                    mode="100644",
                )
                diff_rows, diff_errors = checker.git_tree_diff(
                    self.root,
                    self.base_tree,
                    candidate_tree,
                )
                self.assertEqual(diff_errors, [])

                categorized, errors = checker.derive_authority_rows(
                    diff_rows,
                    ledger,
                )
                scope, scope_error = checker.derive_source_scope(
                    self.root,
                    candidate_tree,
                    path,
                    "100644",
                )

                self.assertEqual(checker.authority_path_kind(path), "production")
                self.assertEqual(scope, "productionSource")
                self.assertIsNone(scope_error)
                self.assertEqual(
                    [row["path"] for row in categorized["extension"]],
                    [path],
                )
                self.assertTrue(
                    any("unknown or ambiguous owner" in error for error in errors),
                    errors,
                )

    def test_vendor_swiftpm_source_anchor_rejects_symlink_and_gitlink(
        self,
    ) -> None:
        cases = (
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Sources/Tokenizers/Tests/DirectoryLink",
                "120000",
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Sources/Tokenizers/Fixtures/Gitlink",
                "160000",
            ),
        )
        ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
        commit = self.candidate_commit(self.base_tree)
        for path, mode in cases:
            with self.subTest(path=path, mode=mode):
                if mode == "120000":
                    candidate_tree, _object_id = self.candidate_tree_with_entry(
                        path,
                        b"../Elsewhere",
                        mode=mode,
                    )
                else:
                    candidate_tree = self.candidate_tree_with_object(
                        path,
                        commit,
                        mode=mode,
                    )
                diff_rows, diff_errors = checker.git_tree_diff(
                    self.root,
                    self.base_tree,
                    candidate_tree,
                )
                self.assertEqual(diff_errors, [])

                categorized, errors = checker.derive_authority_rows(
                    diff_rows,
                    ledger,
                )
                scope, scope_error = checker.derive_source_scope(
                    self.root,
                    candidate_tree,
                    path,
                    mode,
                )

                self.assertEqual(checker.authority_path_kind(path), "production")
                self.assertIsNone(scope)
                self.assertIn("regular tracked file", scope_error or "")
                self.assertFalse(
                    any(
                        row["path"] == path
                        for rows in categorized.values()
                        for row in rows
                    )
                )
                self.assertTrue(
                    any(
                        path in error and "regular tracked file" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_authority_gitlinks_fail_closed_across_nested_topologies(self) -> None:
        paths = (
            "BehavioralAISubstrate/DeviceTestApp/Sources/Gitlink",
            "BehavioralAISubstrate/Cargo/layercore/src/Gitlink",
            "FourthPackage/Sources/Vendor/Gitlink",
            "FourthPackage/Sources/.build/Gitlink",
        )
        ledger = json.loads(LEDGER.read_text(encoding="utf-8"))
        commit = self.candidate_commit(self.base_tree)
        for path in paths:
            with self.subTest(path=path):
                candidate_tree = self.candidate_tree_with_object(
                    path,
                    commit,
                    mode="160000",
                )
                diff_rows, diff_errors = checker.git_tree_diff(
                    self.root,
                    self.base_tree,
                    candidate_tree,
                )
                self.assertEqual(diff_errors, [])

                _categorized, errors = checker.derive_authority_rows(
                    diff_rows,
                    ledger,
                )

                self.assertTrue(
                    any(
                        path in error
                        and "authority namespace" in error
                        and "regular tracked file" in error
                        for error in errors
                    ),
                    errors,
                )

    def test_components_before_authority_root_remain_outside_boundary(self) -> None:
        paths = (
            "Vendor/FourthPackage/Sources/Authority.swift",
            ".build/FourthPackage/Sources/Authority.swift",
            ".swiftpm/FourthPackage/Sources/Authority.swift",
            "DerivedData/FourthPackage/Sources/Authority.swift",
            "FourthPackage/Vendor/Sources/Authority.swift",
            "FourthPackage/.build/Sources/Authority.swift",
            "FourthPackage/.swiftpm/Sources/Authority.swift",
            "FourthPackage/DerivedData/Sources/Authority.swift",
            "BehavioralAISubstrate/Cargo/.build/src/authority.rs",
            "BehavioralAISubstrate/Cargo/Vendor/src/authority.rs",
            "BehavioralAISubstrate/Cargo/DerivedData/tests/authority.rs",
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                ".build/Sources/Tokenizers/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                ".swiftpm/Sources/Tokenizers/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "DerivedData/Sources/Tokenizers/Evil.swift"
            ),
            (
                "BehavioralAISubstrate/Vendor/swift-transformers/"
                "Vendor/Sources/Tokenizers/Evil.swift"
            ),
        )
        for path in paths:
            with self.subTest(path=path):
                self.assertFalse(checker.is_authority_namespace_path(path))
                self.assertFalse(checker.is_authority_diff_path(path))

        governed_after_anchor = (
            "BehavioralAISubstrate/Cargo/layercore/src/Vendor/authority.rs",
            "BehavioralAISubstrate/Cargo/layercore/include/.build/authority.h",
        )
        for path in governed_after_anchor:
            with self.subTest(path=path):
                self.assertTrue(checker.is_authority_namespace_path(path))
                self.assertTrue(checker.is_authority_diff_path(path))

    def test_candidate_blob_budget_charges_one_unique_oid_only_once(self) -> None:
        path = "SampleHost/TestOnlyCandidateBudget/shared.txt"
        tree, object_id = self.candidate_tree_with_entry(
            path,
            b"shared candidate blob\n",
            mode="100644",
        )
        view = checker.CandidateTreeView(
            self.root,
            tree,
            max_unique_blob_reads=1,
            max_cached_blob_bytes=1024,
        )
        with mock.patch.object(
            checker,
            "load_candidate_blob",
            wraps=checker.load_candidate_blob,
        ) as observed:
            first = view.read_text(path, max_bytes=1024, label="shared blob")
            second = view.read_text(path, max_bytes=1024, label="shared blob")

        self.assertEqual(first, second)
        self.assertEqual(observed.call_count, 1)
        self.assertEqual(observed.call_args.args[1], object_id)

    def test_candidate_blob_cap_plus_one_does_not_pollute_cache(self) -> None:
        path = "SampleHost/TestOnlyCandidateBudget/oversize.txt"
        tree, object_id = self.candidate_tree_with_entry(
            path,
            b"12345",
            mode="100644",
        )
        view = checker.CandidateTreeView(
            self.root,
            tree,
            max_unique_blob_reads=2,
            max_cached_blob_bytes=4,
        )

        with self.assertRaisesRegex(
            checker.ContentViewError,
            "cumulative candidate blob cache",
        ):
            view.read_text(path, max_bytes=5, label="oversize blob")

        self.assertNotIn(object_id, view._blob_cache)
        self.assertEqual(view.cached_blob_bytes, 0)

    def test_candidate_terminal_blob_failure_is_memoized_per_oid(self) -> None:
        raw_index = b"100644 blob " + b"1" * 40 + b"\tPackage/Sources/One.swift\0"
        with mock.patch.object(
            checker,
            "load_candidate_tree_index",
            return_value=raw_index,
        ):
            view = checker.CandidateTreeView(
                self.root,
                "a" * 40,
                max_unique_blob_reads=1,
                max_cached_blob_bytes=1024,
            )
        with mock.patch.object(
            checker,
            "run_bounded_process",
            side_effect=OSError("test-only terminal blob failure"),
        ) as observed:
            for _attempt in range(2):
                with self.assertRaises(checker.ContentViewError):
                    view.read_text(
                        "Package/Sources/One.swift",
                        max_bytes=1024,
                        label="terminal blob",
                    )

        self.assertEqual(observed.call_count, 1)

    def test_candidate_size_failure_can_retry_with_a_larger_bound(self) -> None:
        raw_index = b"100644 blob " + b"1" * 40 + b"\tPackage/Sources/One.swift\0"
        with mock.patch.object(
            checker,
            "load_candidate_tree_index",
            return_value=raw_index,
        ):
            view = checker.CandidateTreeView(
                self.root,
                "a" * 40,
                max_unique_blob_reads=1,
                max_cached_blob_bytes=16,
                max_attempted_blob_bytes=16,
            )
        completed = subprocess.CompletedProcess(
            ["git", "cat-file", "blob", "1" * 40],
            0,
            b"12345",
            b"",
        )
        with mock.patch.object(
            checker,
            "run_bounded_process",
            side_effect=(
                checker.ProcessOutputLimitExceeded("test-only cap + 1"),
                completed,
            ),
        ) as observed:
            with self.assertRaises(checker.ContentViewError):
                view.read_text(
                    "Package/Sources/One.swift",
                    max_bytes=4,
                    label="small blob bound",
                )
            contents = view.read_text(
                "Package/Sources/One.swift",
                max_bytes=5,
                label="larger blob bound",
            )

        self.assertEqual(contents, "12345")
        self.assertEqual(observed.call_count, 2)

    def test_candidate_attempted_blob_bytes_charge_failures_before_spawn(
        self,
    ) -> None:
        raw_index = (
            b"100644 blob " + b"1" * 40 + b"\tPackage/Sources/One.swift\0"
            b"100644 blob " + b"2" * 40 + b"\tPackage/Sources/Two.swift\0"
        )
        with mock.patch.object(
            checker,
            "load_candidate_tree_index",
            return_value=raw_index,
        ):
            view = checker.CandidateTreeView(
                self.root,
                "a" * 40,
                max_unique_blob_reads=2,
                max_cached_blob_bytes=16,
                max_blob_load_attempts=2,
                max_attempted_blob_bytes=5,
            )
        with mock.patch.object(
            checker,
            "run_bounded_process",
            side_effect=checker.ProcessOutputLimitExceeded("test-only oversized blob"),
        ) as observed:
            with self.assertRaises(checker.ContentViewError):
                view.read_text(
                    "Package/Sources/One.swift",
                    max_bytes=4,
                    label="first oversized blob",
                )
            with self.assertRaisesRegex(
                checker.ContentViewError,
                "attempted candidate blob byte budget",
            ):
                view.read_text(
                    "Package/Sources/Two.swift",
                    max_bytes=1,
                    label="second blob",
                )

        self.assertEqual(observed.call_count, 1)

    def test_candidate_success_settles_attempted_bytes_to_actual_output(
        self,
    ) -> None:
        raw_index = (
            b"100644 blob " + b"1" * 40 + b"\tPackage/Sources/One.swift\0"
            b"100644 blob " + b"2" * 40 + b"\tPackage/Sources/Two.swift\0"
        )
        with mock.patch.object(
            checker,
            "load_candidate_tree_index",
            return_value=raw_index,
        ):
            view = checker.CandidateTreeView(
                self.root,
                "a" * 40,
                max_unique_blob_reads=2,
                max_cached_blob_bytes=16,
                max_blob_load_attempts=2,
                max_attempted_blob_bytes=5,
            )
        with mock.patch.object(
            checker,
            "load_candidate_blob",
            return_value=b"1234",
        ) as observed:
            self.assertEqual(
                view.read_text(
                    "Package/Sources/One.swift",
                    max_bytes=4,
                    label="exact reservation",
                ),
                "1234",
            )
            with self.assertRaisesRegex(
                checker.ContentViewError,
                "attempted candidate blob byte budget",
            ):
                view.read_text(
                    "Package/Sources/Two.swift",
                    max_bytes=1,
                    label="cap plus one",
                )

        self.assertEqual(view.attempted_blob_bytes, 4)
        self.assertEqual(observed.call_count, 1)

    def test_candidate_blob_load_attempt_budget_precedes_spawn(self) -> None:
        raw_index = (
            b"100644 blob " + b"1" * 40 + b"\tPackage/Sources/One.swift\0"
            b"100644 blob " + b"2" * 40 + b"\tPackage/Sources/Two.swift\0"
        )
        with mock.patch.object(
            checker,
            "load_candidate_tree_index",
            return_value=raw_index,
        ):
            view = checker.CandidateTreeView(
                self.root,
                "a" * 40,
                max_unique_blob_reads=2,
                max_cached_blob_bytes=16,
                max_blob_load_attempts=1,
                max_attempted_blob_bytes=16,
            )
        with mock.patch.object(
            checker,
            "load_candidate_blob",
            return_value=b"x",
        ) as observed:
            view.read_text(
                "Package/Sources/One.swift",
                max_bytes=1,
                label="first blob",
            )
            with self.assertRaisesRegex(
                checker.ContentViewError,
                "candidate blob-load attempt budget",
            ):
                view.read_text(
                    "Package/Sources/Two.swift",
                    max_bytes=1,
                    label="second blob",
                )

        self.assertEqual(observed.call_count, 1)

    def test_candidate_blob_default_wall_budget_preserves_git_timeout(
        self,
    ) -> None:
        raw_index = b"100644 blob " + b"1" * 40 + b"\tPackage/Sources/One.swift\0"
        clock = [0.0]
        with (
            mock.patch.object(
                checker,
                "load_candidate_tree_index",
                return_value=raw_index,
            ),
            mock.patch.object(
                checker,
                "monotonic",
                side_effect=lambda: clock[0],
            ),
        ):
            view = checker.CandidateTreeView(
                self.root,
                "a" * 40,
                max_unique_blob_reads=1,
                max_cached_blob_bytes=1,
            )
            observed_timeouts: list[float] = []

            def load_tiny_blob(*args, **kwargs) -> bytes:
                timeout_seconds = kwargs.get("timeout_seconds")
                if timeout_seconds is None:
                    self.fail(
                        "candidate blob loader did not receive its remaining "
                        "wall-clock timeout"
                    )
                observed_timeouts.append(timeout_seconds)
                return b"x"

            with mock.patch.object(
                checker,
                "load_candidate_blob",
                side_effect=load_tiny_blob,
            ):
                contents = view.read_text(
                    "Package/Sources/One.swift",
                    max_bytes=1,
                    label="default wall budget",
                )

        self.assertEqual(contents, "x")
        self.assertEqual(
            observed_timeouts,
            [30],
        )

    def test_candidate_blob_wall_deadline_bounds_thousands_of_tiny_loads(
        self,
    ) -> None:
        entry_count = 4_096
        raw_index = b"".join(
            (f"100644 blob {index:040x}\tPackage/Sources/{index:04d}.swift\0").encode(
                "ascii"
            )
            for index in range(entry_count)
        )
        clock = [0]
        observed_timeouts: list[float] = []

        def fake_monotonic() -> float:
            return clock[0] / entry_count

        def load_tiny_blob(*args, **kwargs) -> bytes:
            timeout_seconds = kwargs.get("timeout_seconds")
            if timeout_seconds is None:
                self.fail("candidate blob loader did not receive a bounded timeout")
            observed_timeouts.append(timeout_seconds)
            clock[0] += 1
            return b"x"

        with (
            mock.patch.object(
                checker,
                "load_candidate_tree_index",
                return_value=raw_index,
            ),
            mock.patch.object(
                checker,
                "monotonic",
                side_effect=fake_monotonic,
            ),
        ):
            try:
                view = checker.CandidateTreeView(
                    self.root,
                    "a" * 40,
                    max_unique_blob_reads=entry_count,
                    max_cached_blob_bytes=entry_count,
                    max_blob_load_attempts=entry_count,
                    max_attempted_blob_bytes=entry_count,
                    max_blob_wall_seconds=1.0,
                )
            except TypeError as error:
                self.fail(
                    "CandidateTreeView has no cumulative blob wall-clock "
                    f"budget: {error}"
                )
            with mock.patch.object(
                checker,
                "load_candidate_blob",
                side_effect=load_tiny_blob,
            ):
                for index in range(entry_count - 1):
                    self.assertEqual(
                        view.read_text(
                            f"Package/Sources/{index:04d}.swift",
                            max_bytes=1,
                            label="tiny candidate blob",
                        ),
                        "x",
                    )
                clock[0] = entry_count
                with self.assertRaisesRegex(
                    checker.ContentViewError,
                    "wall-clock deadline",
                ):
                    view.read_text(
                        f"Package/Sources/{entry_count - 1:04d}.swift",
                        max_bytes=1,
                        label="deadline candidate blob",
                    )

        self.assertEqual(view.blob_load_attempts, entry_count - 1)
        self.assertEqual(len(observed_timeouts), entry_count - 1)
        self.assertEqual(observed_timeouts[0], 1.0)
        self.assertEqual(observed_timeouts[-1], 2 / 4_096)

    def test_candidate_blob_wall_deadline_rejects_above_outer_bound(
        self,
    ) -> None:
        with mock.patch.object(
            checker,
            "load_candidate_tree_index",
            return_value=b"",
        ):
            try:
                with self.assertRaisesRegex(
                    checker.ContentViewError,
                    "wall-clock.*at most 120",
                ):
                    checker.CandidateTreeView(
                        self.root,
                        "a" * 40,
                        max_blob_wall_seconds=120.001,
                    )
            except TypeError as error:
                self.fail(
                    "CandidateTreeView does not validate a standalone wall "
                    f"clock bound: {error}"
                )

    def test_default_attempted_blob_budget_includes_all_lookahead_bytes(
        self,
    ) -> None:
        self.assertEqual(
            checker.MAX_CANDIDATE_ATTEMPTED_BLOB_BYTES,
            checker.MAX_CANDIDATE_CACHED_BLOB_BYTES
            + checker.MAX_CANDIDATE_BLOB_LOAD_ATTEMPTS,
        )

    def test_candidate_unique_blob_read_budget_fails_before_second_read(
        self,
    ) -> None:
        raw_index = (
            b"100644 blob " + b"1" * 40 + b"\tPackage/Sources/One.swift\0"
            b"100644 blob " + b"2" * 40 + b"\tPackage/Sources/Two.swift\0"
        )
        with mock.patch.object(
            checker,
            "load_candidate_tree_index",
            return_value=raw_index,
        ):
            view = checker.CandidateTreeView(
                self.root,
                "a" * 40,
                max_unique_blob_reads=1,
                max_cached_blob_bytes=1024,
            )
        with mock.patch.object(
            checker,
            "load_candidate_blob",
            return_value=b"public struct Value {}\n",
        ) as observed:
            view.read_text(
                "Package/Sources/One.swift",
                max_bytes=1024,
                label="first blob",
            )
            with self.assertRaisesRegex(
                checker.ContentViewError,
                "unique candidate blob-read budget",
            ):
                view.read_text(
                    "Package/Sources/Two.swift",
                    max_bytes=1024,
                    label="second blob",
                )

        self.assertEqual(observed.call_count, 1)

    def test_candidate_glob_budget_rejects_malicious_200k_match_tree(
        self,
    ) -> None:
        raw_index = b"".join(
            b"100644 blob "
            + b"1" * 40
            + f"\tPackage/Sources/File{index:06d}.swift".encode("ascii")
            + b"\0"
            for index in range(200_000)
        )
        with mock.patch.object(
            checker,
            "load_candidate_tree_index",
            return_value=raw_index,
        ):
            view = checker.CandidateTreeView(
                self.root,
                "a" * 40,
                max_glob_matches=64,
                max_total_glob_matches=128,
            )

        with self.assertRaisesRegex(
            checker.ContentViewError,
            "candidate glob match budget",
        ):
            view.glob("Package", "**/*.swift")

    def test_candidate_build_surface_budget_is_fail_closed(self) -> None:
        class ExcessiveBuildSurfaceView:
            def glob(self, _base: str, _pattern: str) -> list[str]:
                return [
                    f"SampleHost/Generated{index:04d}/Package.swift"
                    for index in range(checker.MAX_CANDIDATE_BUILD_SURFACES + 1)
                ]

        with self.assertRaisesRegex(
            checker.ContentViewError,
            "candidate build-surface budget",
        ):
            checker.owned_production_build_surfaces(
                ExcessiveBuildSurfaceView(),
            )

    def test_cli_reads_controlled_documents_only_from_candidate_tree(
        self,
    ) -> None:
        relative_path = checker.EXPECTED_CONTROLLED_DOCUMENTS[0]
        live = (ROOT / relative_path).read_text(encoding="utf-8")
        required_term = next(
            term
            for term in sorted(checker.MANDATORY_DOCUMENT_SPECIFIC_TERMS[relative_path])
            if term in live
        )
        candidate = live.replace(required_term, "candidate-removed-term", 1)
        self.candidate_tree = self.candidate_tree_with_blob(
            relative_path,
            candidate.encode("utf-8"),
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("missing required term", result.stderr)
        self.assertIn(required_term, result.stderr)

    def test_live_only_xcodegen_surface_does_not_affect_candidate_gate(
        self,
    ) -> None:
        relative_path = "SampleHost/TestOnlyCandidateTreeView/project.yml"
        live_path = self.root / relative_path
        live_path.parent.mkdir(parents=True, exist_ok=True)
        live_path.write_text(
            "targets:\n"
            "  TestOnly:\n"
            "    sources:\n"
            "      - ../../scripts/check_qinao_owner_ledger.py\n",
            encoding="utf-8",
        )
        self.addCleanup(live_path.unlink)

        result = self.run_gate()

        self.assertEqual(result.returncode, 0, result.stderr)

    def test_candidate_only_xcodegen_surface_is_audited_when_live_missing(
        self,
    ) -> None:
        relative_path = "SampleHost/TestOnlyCandidateTreeView/project.yml"
        self.assertFalse((self.root / relative_path).exists())
        self.candidate_tree = self.candidate_tree_with_blob(
            relative_path,
            (
                "targets:\n"
                "  TestOnly:\n"
                "    sources:\n"
                "      - ../../scripts/check_qinao_owner_ledger.py\n"
            ).encode("utf-8"),
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("audit asset", result.stderr)
        self.assertIn(relative_path, result.stderr)

    def test_candidate_view_is_immutable_after_live_path_swap(self) -> None:
        relative_path = "SampleHost/TestOnlyCandidateTreeView/value.txt"
        candidate_bytes = b"candidate-only bytes\n"
        tree = self.candidate_tree_with_blob(relative_path, candidate_bytes)
        view = checker.CandidateTreeView(self.root, tree)
        live_path = self.root / relative_path
        live_path.parent.mkdir(parents=True, exist_ok=True)
        live_path.write_bytes(b"attacker live bytes\n")
        self.addCleanup(live_path.unlink)

        self.assertEqual(
            view.read_text(
                relative_path,
                max_bytes=1024,
                label="test-only candidate value",
            ),
            candidate_bytes.decode("utf-8"),
        )

    def test_candidate_validation_performs_no_live_content_path_reads(
        self,
    ) -> None:
        data = json.loads(LEDGER.read_text(encoding="utf-8"))
        executed_source = SCRIPT.read_text(encoding="utf-8")
        view = checker.CandidateTreeView(self.root, self.base_tree)

        def forbidden(*_args, **_kwargs):
            raise AssertionError("candidate validation attempted a live path read")

        with (
            mock.patch.object(
                Path,
                "read_text",
                new=forbidden,
            ),
            mock.patch.object(
                Path,
                "is_file",
                new=forbidden,
            ),
            mock.patch.object(
                Path,
                "exists",
                new=forbidden,
            ),
            mock.patch.object(
                Path,
                "glob",
                new=forbidden,
            ),
        ):
            errors = checker.validate_ledger(
                data,
                self.root,
                executed_owner_gate_source=executed_source,
                content_view=view,
            )

        self.assertEqual(errors, [])

    def test_live_only_history_and_m_paths_remain_absent_in_candidate_view(
        self,
    ) -> None:
        data = json.loads(LEDGER.read_text(encoding="utf-8"))
        view = checker.CandidateTreeView(self.root, self.base_tree)
        m_path = next(
            permission["allowed_paths"][0]
            for permission in data["create_permissions"]
            if permission["owner_id"] == "execution.state-abi"
        )
        history_path = checker.HISTORY_DOCTRINE_AUDIT_PATHS[0]
        for relative_path in (m_path, history_path):
            self.assertFalse(view.is_file(relative_path))
            live_path = self.root / relative_path
            live_path.parent.mkdir(parents=True, exist_ok=True)
            live_path.write_text("test-only live substitution\n", encoding="utf-8")
            self.addCleanup(live_path.unlink)

        errors = checker.validate_ledger(
            data,
            self.root,
            executed_owner_gate_source=SCRIPT.read_text(encoding="utf-8"),
            content_view=view,
        )

        self.assertFalse(
            any("approved_missing" in error for error in errors),
            errors,
        )
        self.assertFalse(
            any("cannot coexist with BASHistoryAudit" in error for error in errors),
            errors,
        )

    def test_live_only_evidence_path_is_absent_from_candidate_view(self) -> None:
        data = json.loads(LEDGER.read_text(encoding="utf-8"))
        relative_path = "SampleHost/Sources/TestOnlyCandidateTreeViewEvidence.swift"
        live_path = self.root / relative_path
        live_path.parent.mkdir(parents=True, exist_ok=True)
        live_path.write_text("public struct LiveOnlyEvidence {}\n", encoding="utf-8")
        self.addCleanup(live_path.unlink)
        mutated = copy.deepcopy(data)
        mutated["owners"][0]["evidence_paths"].append(relative_path)
        view = checker.CandidateTreeView(self.root, self.base_tree)

        errors = checker.validate_ledger(
            mutated,
            self.root,
            executed_owner_gate_source=SCRIPT.read_text(encoding="utf-8"),
            content_view=view,
        )

        self.assertTrue(
            any(
                f"evidence path does not exist: {relative_path}" in error
                for error in errors
            ),
            errors,
        )

    def test_all_required_wave_arguments_are_accepted_and_valid_w0_passes(self) -> None:
        result = self.run_gate()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("create=0", result.stdout)
        self.assertIn("extension=0", result.stdout)
        self.assertIn("adapter=0", result.stdout)
        self.assertIn("fixture=0", result.stdout)

    def test_source_selection_requires_the_frozen_approved_design_tuple(self) -> None:
        design_path = self.DESIGN_PATH.relative_to(ROOT).as_posix()
        design_binding = checker.git_tree_blob(ROOT, self.base_tree, design_path)
        self.assertIsNotNone(design_binding)
        assert design_binding is not None
        design_blob, design_bytes = design_binding

        self.mutate_source_selection(
            lambda document: document.__setitem__(
                "approvedDesign",
                {
                    "path": design_path,
                    "commit": self.git("rev-parse", "HEAD"),
                    "tree": self.base_tree,
                    "blob": design_blob,
                    "byteLength": len(design_bytes),
                    "sha256": hashlib.sha256(design_bytes).hexdigest(),
                },
            )
        )

        errors = self.source_selection_errors()

        self.assertTrue(
            any(
                "approvedDesign must equal the frozen tuple" in error
                for error in errors
            ),
            errors,
        )

    def test_source_selection_rederives_complete_committed_rows(self) -> None:
        self.mutate_source_selection(
            lambda document: document["candidateComparisons"][0].__setitem__(
                "committedRows",
                [
                    {
                        "path": "SampleHost/Sources/Forged.swift",
                        "change": "add",
                        "scope": "productionSource",
                    }
                ],
            )
        )

        errors = self.source_selection_errors()

        self.assertTrue(
            any(
                "committedRows do not match Git derivation" in error for error in errors
            ),
            errors,
        )

    def test_source_selection_rejects_dirty_nonselected_comparison(self) -> None:
        def add_dirty_nonselected(document: dict) -> None:
            comparison = copy.deepcopy(document["candidateComparisons"][0])
            comparison["candidateID"] = "nonselected-worktree"
            comparison["selected"] = False
            comparison["untrackedRows"] = [
                {
                    "path": "scratch.txt",
                    "change": "untracked",
                    "scope": "other",
                }
            ]
            document["candidateComparisons"].append(comparison)
            document["candidateComparisons"].sort(key=_canonical_test_json)

        self.mutate_source_selection(add_dirty_nonselected)

        errors = self.source_selection_errors()

        self.assertTrue(
            any(
                "candidateComparisons[" in error
                and "untrackedRows must be empty" in error
                for error in errors
            ),
            errors,
        )

    def test_git_committed_rows_are_nul_derived_and_rfc8785_sorted(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)

            def git(*arguments: str) -> str:
                completed = subprocess.run(
                    ["git", *arguments],
                    cwd=root,
                    check=True,
                    capture_output=True,
                    text=True,
                )
                return completed.stdout.strip()

            git("init", "-q")
            git("config", "user.email", "test-only@example.invalid")
            git("config", "user.name", "Qinao Test Only")
            workflow = root / ".github/workflows/qinao-wave-admission.yml"
            workflow.parent.mkdir(parents=True)
            workflow.write_text("name: base\n", encoding="utf-8")
            git("add", ".github/workflows/qinao-wave-admission.yml")
            git("commit", "-qm", "test-only base")
            base_tree = git("rev-parse", "HEAD^{tree}")
            workflow.write_text("name: candidate\n", encoding="utf-8")
            fixture = (
                root / "scripts/fixtures/qinao_admission_canonical_vectors_v1.json"
            )
            fixture.parent.mkdir(parents=True)
            fixture.write_text("{}\n", encoding="utf-8")
            git("add", ".github/workflows/qinao-wave-admission.yml")
            git(
                "add",
                "scripts/fixtures/qinao_admission_canonical_vectors_v1.json",
            )
            candidate_tree = git("write-tree")

            rows, errors = checker.derive_committed_source_rows(
                root,
                base_tree,
                candidate_tree,
            )

        self.assertEqual(errors, [])
        self.assertIsNotNone(rows)
        assert rows is not None
        self.assertEqual(rows, sorted(rows, key=_canonical_test_json))
        self.assertIn(
            {
                "path": ".github/workflows/qinao-wave-admission.yml",
                "change": "modify",
                "scope": "ci",
            },
            rows,
        )
        self.assertIn(
            {
                "path": "scripts/fixtures/qinao_admission_canonical_vectors_v1.json",
                "change": "add",
                "scope": "checker",
            },
            rows,
        )

    def test_amendment_2_source_scope_rules_are_closed(self) -> None:
        cases = {
            "docs/superpowers/specs/qinao-owner-ledger-v1.json": "ownerLedger",
            "scripts/check_qinao_owner_ledger.py": "checker",
            ".github/workflows/qinao.yml": "ci",
            "BehavioralAISubstrate/Cargo/layercore/Cargo.toml": "productionSource",
            "BehavioralAISubstrate/Cargo/layercore/src/lib.rs": "productionSource",
            "BehavioralAISubstrate/Cargo/layercore/include/layer.h": (
                "productionSource"
            ),
            "BehavioralAISubstrate/Cargo/layercore/generated/src/lib.rs": "other",
            "SampleHost/Sources/App.swift": "productionSource",
            "SampleHost/README.md": "other",
            "SampleHost/Tests/AppTests.swift": "other",
            "SampleHost/.build/generated.swift": "other",
            "SampleHost/Sources/cache.tmp": "productionSource",
            "docs/uncontrolled.md": "other",
        }

        for path, expected_scope in cases.items():
            with self.subTest(path=path):
                scope, error = checker.derive_source_scope(
                    ROOT,
                    self.base_tree,
                    path,
                    "100644",
                )
                self.assertIsNone(error)
                self.assertEqual(scope, expected_scope)

        nested_scope, nested_error = checker.derive_source_scope(
            ROOT,
            self.base_tree,
            ".github/workflows/nested/qinao.yml",
            "100644",
        )
        self.assertIsNone(nested_scope)
        self.assertIn("nested workflow", nested_error or "")

    def test_authority_predicate_covers_any_top_level_package_and_exclusions(
        self,
    ) -> None:
        authority_paths = (
            "FourthPackage/Package.swift",
            "FourthPackage/Sources/Feature.swift",
            "FourthPackage/Sources/SQL/schema.sql",
            "FourthPackage/Tests/FeatureTests.swift",
            "FourthPackage/Fixtures/state.json",
        )
        excluded_paths = (
            ".git/FourthPackage/Tests/Hidden.swift",
            "Vendor/FourthPackage/Tests/Vendored.swift",
            "FourthPackage/.build/Tests/Generated.swift",
            "FourthPackage/DerivedData/Tests/Generated.swift",
        )
        for path in authority_paths:
            with self.subTest(authority=path):
                self.assertTrue(checker.is_authority_diff_path(path))
        for path in excluded_paths:
            with self.subTest(excluded=path):
                self.assertFalse(checker.is_authority_diff_path(path))

    def test_authority_namespace_is_independent_from_file_extensions(self) -> None:
        boundary_paths = (
            "FourthPackage/Sources/DirectoryLink",
            "FourthPackage/Tests/FixtureDirectory",
            "FourthPackage/Fixtures/Corpus",
            "BehavioralAISubstrate/DeviceTestApp/Sources/DirectoryLink",
            "FourthPackage/Sources/Vendor/DirectoryLink",
            "FourthPackage/Sources/.build/DirectoryLink",
            "BehavioralAISubstrate/Cargo/layercore/src/GeneratedLink",
            "BehavioralAISubstrate/Cargo/layercore/include/GeneratedLink",
        )
        excluded_paths = (
            ".git/FourthPackage/Sources/DirectoryLink",
            "Vendor/FourthPackage/Sources/DirectoryLink",
            "FourthPackage/.build/Sources/DirectoryLink",
            "FourthPackage/DerivedData/Tests/FixtureDirectory",
        )

        for path in boundary_paths:
            with self.subTest(boundary=path):
                self.assertTrue(checker.is_authority_namespace_path(path))
                self.assertTrue(checker.is_authority_diff_path(path))
        for path in excluded_paths:
            with self.subTest(excluded=path):
                self.assertFalse(checker.is_authority_namespace_path(path))

    def test_authority_namespace_special_mode_fails_source_scope_closed(
        self,
    ) -> None:
        scope, error = checker.derive_source_scope(
            ROOT,
            self.base_tree,
            "FourthPackage/Sources/DirectoryLink",
            "120000",
        )

        self.assertIsNone(scope)
        self.assertIn("authority namespace", error or "")
        self.assertIn("regular tracked file", error or "")

    def test_workspace_path_normalization_is_strict(self) -> None:
        self.assertTrue(
            checker.is_normalized_workspace_path(
                "BehavioralAISubstrate/Sources/Runtime.swift"
            )
        )
        invalid_paths = (
            ".",
            "Sources/./Runtime.swift",
            "Sources/../Runtime.swift",
            "Sources//Runtime.swift",
            "Sources/\x00Runtime.swift",
            "Sources/\tRuntime.swift",
            "Sources/\nRuntime.swift",
            "Sources/\x7fRuntime.swift",
            "Sources/\x85Runtime.swift",
            "Sources/Cafe\u0301.swift",
            "Sources/\ud800.swift",
        )
        for path in invalid_paths:
            with self.subTest(path=repr(path)):
                self.assertFalse(checker.is_normalized_workspace_path(path))

    def test_git_committed_row_derivation_rejects_non_normalized_raw_paths(
        self,
    ) -> None:
        raw_paths = (
            b"",
            b".",
            b"Sources/./Runtime.swift",
            b"Sources/\x00Runtime.swift",
            b"Sources/\tRuntime.swift",
            b"Sources/\nRuntime.swift",
            b"Sources/\x7fRuntime.swift",
            "Sources/\x85Runtime.swift".encode("utf-8"),
            "Sources/Cafe\u0301.swift".encode("utf-8"),
            b"Sources/\xff.swift",
        )
        metadata = b":000000 100644 " + (b"0" * 40) + b" " + (b"1" * 40) + b" A\0"
        for raw_path in raw_paths:
            with self.subTest(raw_path=raw_path):
                completed = subprocess.CompletedProcess(
                    ["git", "diff-tree"],
                    0,
                    stdout=metadata + raw_path + b"\0",
                    stderr=b"",
                )
                with mock.patch.object(
                    checker,
                    "run_bounded_process",
                    return_value=completed,
                ):
                    rows, errors = checker.derive_committed_source_rows(
                        ROOT,
                        self.base_tree,
                        self.base_tree,
                    )

                self.assertIsNone(rows)
                self.assertTrue(errors)

    def test_git_committed_row_derivation_rejects_truncated_nul_stream(self) -> None:
        raw = (
            b":100644 100644 "
            + (b"1" * 40)
            + b" "
            + (b"2" * 40)
            + b" M\0scripts/check_qinao_owner_ledger.py"
        )
        completed = subprocess.CompletedProcess(
            ["git", "diff-tree"],
            0,
            stdout=raw,
            stderr=b"",
        )

        with mock.patch.object(
            checker,
            "run_bounded_process",
            return_value=completed,
        ):
            rows, errors = checker.derive_committed_source_rows(
                ROOT,
                self.base_tree,
                self.base_tree,
            )

        self.assertIsNone(rows)
        self.assertTrue(
            any("truncated NUL" in error for error in errors),
            errors,
        )

    def test_git_committed_row_derivation_rejects_unknown_status(self) -> None:
        raw = (
            b":100644 100644 "
            + (b"1" * 40)
            + b" "
            + (b"2" * 40)
            + b" X\0scripts/check_qinao_owner_ledger.py\0"
        )
        completed = subprocess.CompletedProcess(
            ["git", "diff-tree"],
            0,
            stdout=raw,
            stderr=b"",
        )

        with mock.patch.object(
            checker,
            "run_bounded_process",
            return_value=completed,
        ):
            rows, errors = checker.derive_committed_source_rows(
                ROOT,
                self.base_tree,
                self.base_tree,
            )

        self.assertIsNone(rows)
        self.assertTrue(
            any("status 'X' is unsupported" in error for error in errors),
            errors,
        )

    def test_vendor_descendant_requires_bound_tree_manifest_membership(self) -> None:
        scope, error = checker.derive_source_scope(
            ROOT,
            self.base_tree,
            "scripts/vendor/qinao_jsonschema_draft202012_v1/jsonschema/__init__.py",
            "100644",
        )

        self.assertIsNone(scope)
        self.assertIn("bound vendor manifest", error or "")

    def test_git_committed_row_derivation_rejects_special_mode_type_change(
        self,
    ) -> None:
        raw = (
            b":100644 160000 "
            + (b"1" * 40)
            + b" "
            + (b"2" * 40)
            + b" T\0scripts/check_qinao_owner_ledger.py\0"
        )
        completed = subprocess.CompletedProcess(
            ["git", "diff-tree"],
            0,
            stdout=raw,
            stderr=b"",
        )

        with mock.patch.object(
            checker,
            "run_bounded_process",
            return_value=completed,
        ):
            rows, errors = checker.derive_committed_source_rows(
                ROOT,
                self.base_tree,
                self.base_tree,
            )

        self.assertIsNone(rows)
        self.assertTrue(
            any("special Git mode" in error for error in errors),
            errors,
        )

    def test_internal_fixture_predicate_keeps_frozen_test_roots(self) -> None:
        fixture_paths = (
            "BehavioralAISubstrate/Tests/LayerCoreTests.swift",
            "BehavioralAISubstrate/Cargo/layercore/tests/integration.rs",
            "BehavioralAISubstrate/Cargo/layercore/benches/throughput.rs",
            "BehavioralAISubstrate/DeviceTestApp/Tests/AppTests.swift",
            "QinaoRuntimeSDK/Tests/RuntimeTests.swift",
            "SampleHost/Tests/HostTests.swift",
            "scripts/fixtures/non-authority-fixture.json",
        )
        for path in fixture_paths:
            with self.subTest(path=path):
                self.assertTrue(checker._is_internal_fixture_path(path))
        for path in (
            "SampleHost/Tests/.hidden.swift",
            "SampleHost/Tests/Backups/old.swift",
            "SampleHost/Tests/cache.tmp",
        ):
            with self.subTest(path=path):
                self.assertFalse(checker._is_internal_fixture_path(path))

    def test_draft202012_profile_rejects_scalar_enum(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["enum"] = "not-an-array"

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any("enum must be an array" in error for error in errors), errors
        )

    def test_draft202012_profile_rejects_nonlocal_ref(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$ref"] = "https://example.invalid/schema"

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any("$ref must be same-document" in error for error in errors), errors
        )

    def test_draft202012_profile_rejects_nonlocal_dynamic_ref(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$dynamicRef"] = "qinao://schemas/foreign/1.0.0"

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any("$dynamicRef must be a local anchor" in error for error in errors),
            errors,
        )

    def test_draft202012_profile_rejects_wrong_required_type(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["required"] = "value"

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any(
                "required must be an array of unique strings" in error
                for error in errors
            ),
            errors,
        )

    def test_draft202012_profile_rejects_wrong_type_keyword_type(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["type"] = 7

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(any("type is invalid" in error for error in errors), errors)

    def test_draft202012_profile_rejects_wrong_one_of_type(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["oneOf"] = {"type": "string"}

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any("oneOf must be a schema array" in error for error in errors), errors
        )

    def test_draft202012_profile_rejects_wrong_dependent_required_type(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["dependentRequired"] = {"name": "value"}

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any(
                "dependentRequired values must be arrays of unique strings" in error
                for error in errors
            ),
            errors,
        )

    def test_draft202012_profile_closes_keyword_value_types(self) -> None:
        invalid_values = {
            "$comment": None,
            "title": 7,
            "description": [],
            "deprecated": 0,
            "readOnly": 1,
            "writeOnly": "false",
            "uniqueItems": None,
            "examples": {},
            "maximum": "1",
            "minimum": [],
            "exclusiveMaximum": None,
            "exclusiveMinimum": True,
            "maxContains": "1",
            "minContains": False,
            "maxItems": None,
            "minItems": [],
            "maxLength": "1",
            "minLength": True,
            "maxProperties": {},
            "minProperties": False,
            "multipleOf": "1",
        }
        for keyword, invalid in invalid_values.items():
            with self.subTest(keyword=keyword):
                schema = self.valid_draft202012_profile_schema()
                schema[keyword] = invalid

                errors = checker.validate_qinao_draft202012_profile(schema)

                self.assertTrue(
                    any(keyword in error for error in errors),
                    errors,
                )

    def test_draft202012_profile_enforces_integer_keyword_boundaries(
        self,
    ) -> None:
        safe = 9007199254740991
        signed_keywords = (
            "maximum",
            "minimum",
            "exclusiveMaximum",
            "exclusiveMinimum",
        )
        nonnegative_keywords = (
            "maxContains",
            "minContains",
            "maxItems",
            "minItems",
            "maxLength",
            "minLength",
            "maxProperties",
            "minProperties",
        )
        for keyword in signed_keywords:
            for accepted in (-safe, -1, 0, 1, safe):
                with self.subTest(keyword=keyword, accepted=accepted):
                    schema = self.valid_draft202012_profile_schema()
                    schema[keyword] = accepted
                    self.assertEqual(
                        checker.validate_qinao_draft202012_profile(schema),
                        [],
                    )
            for rejected in (False, True, -safe - 1, safe + 1):
                with self.subTest(keyword=keyword, rejected=rejected):
                    schema = self.valid_draft202012_profile_schema()
                    schema[keyword] = rejected
                    errors = checker.validate_qinao_draft202012_profile(schema)
                    self.assertTrue(
                        any(keyword in error for error in errors),
                        errors,
                    )
        for keyword in nonnegative_keywords:
            for accepted in (0, 1, safe):
                with self.subTest(keyword=keyword, accepted=accepted):
                    schema = self.valid_draft202012_profile_schema()
                    schema[keyword] = accepted
                    self.assertEqual(
                        checker.validate_qinao_draft202012_profile(schema),
                        [],
                    )
            for rejected in (-1, False, True, safe + 1):
                with self.subTest(keyword=keyword, rejected=rejected):
                    schema = self.valid_draft202012_profile_schema()
                    schema[keyword] = rejected
                    errors = checker.validate_qinao_draft202012_profile(schema)
                    self.assertTrue(
                        any(keyword in error for error in errors),
                        errors,
                    )
        for accepted in (1, safe):
            with self.subTest(keyword="multipleOf", accepted=accepted):
                schema = self.valid_draft202012_profile_schema()
                schema["multipleOf"] = accepted
                self.assertEqual(
                    checker.validate_qinao_draft202012_profile(schema),
                    [],
                )
        for rejected in (-1, 0, False, True, safe + 1):
            with self.subTest(keyword="multipleOf", rejected=rejected):
                schema = self.valid_draft202012_profile_schema()
                schema["multipleOf"] = rejected
                errors = checker.validate_qinao_draft202012_profile(schema)
                self.assertTrue(
                    any("multipleOf" in error for error in errors),
                    errors,
                )

    def test_draft202012_profile_accepts_empty_controls_and_instance_data(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema.update(
            {
                "$comment": "",
                "title": "",
                "description": "",
                "deprecated": False,
                "readOnly": False,
                "writeOnly": True,
                "uniqueItems": False,
                "const": {"nested": [None, False, 0, ""]},
                "default": [],
                "examples": [],
                "maximum": 1,
                "minimum": -1,
                "exclusiveMaximum": 1,
                "exclusiveMinimum": -1,
                "maxContains": 0,
                "minContains": 0,
                "maxItems": 0,
                "minItems": 0,
                "maxLength": 0,
                "minLength": 0,
                "maxProperties": 0,
                "minProperties": 0,
                "multipleOf": 1,
            }
        )

        self.assertEqual(
            checker.validate_qinao_draft202012_profile(schema),
            [],
        )

    def test_draft202012_profile_accepts_local_cycle_and_ignores_const_data(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$defs"] = {
            "node": {
                "$anchor": "node",
                "properties": {
                    "next": {"$ref": "#node"},
                },
            }
        }
        schema["properties"]["root"] = {"$ref": "#/$defs/node"}
        schema["const"] = {"looksLikeSchema": {"$ref": "https://data.invalid"}}

        self.assertEqual(
            checker.validate_qinao_draft202012_profile(schema),
            [],
        )

    def test_local_pointer_resolver_is_strict_rfc6901_and_array_safe(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["prefixItems"] = [{"type": "string"}]
        schema["$defs"] = {
            "slash/name": {"type": "integer"},
            "tilde~name": {"type": "boolean"},
        }
        accepted = {
            "#": schema,
            "#/prefixItems/0": schema["prefixItems"][0],
            "#/$defs/slash~1name": schema["$defs"]["slash/name"],
            "#/$defs/tilde~0name": schema["$defs"]["tilde~name"],
        }
        for reference, expected in accepted.items():
            with self.subTest(accepted=reference):
                resolved, target = checker.resolve_qinao_local_json_pointer(
                    schema,
                    reference,
                )
                self.assertTrue(resolved)
                self.assertIs(target, expected)

        for reference in (
            "#/prefixItems/1",
            "#/prefixItems/00",
            "#/prefixItems/-1",
            "#/prefixItems/" + ("9" * 10000),
            "#/$defs/slash~2name",
            "#/$defs/tilde~",
        ):
            with self.subTest(rejected=reference):
                self.assertEqual(
                    checker.resolve_qinao_local_json_pointer(
                        schema,
                        reference,
                    ),
                    (False, None),
                )

    def test_draft202012_profile_accepts_array_pointer_and_rejects_bad_indices(
        self,
    ) -> None:
        accepted = self.valid_draft202012_profile_schema()
        accepted["prefixItems"] = [{"type": "string"}]
        accepted["$ref"] = "#/prefixItems/0"
        self.assertEqual(
            checker.validate_qinao_draft202012_profile(accepted),
            [],
        )

        for reference in (
            "#/prefixItems/1",
            "#/prefixItems/00",
            "#/prefixItems/" + ("9" * 10000),
        ):
            with self.subTest(reference=reference):
                rejected = self.valid_draft202012_profile_schema()
                rejected["prefixItems"] = [{"type": "string"}]
                rejected["$ref"] = reference
                errors = checker.validate_qinao_draft202012_profile(rejected)
                self.assertTrue(
                    any("$ref target is unresolved" in error for error in errors),
                    errors,
                )

    def test_same_document_schema_resolver_separates_anchor_classes(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        static_target = {"$anchor": "staticTarget", "type": "string"}
        dynamic_target = {
            "$dynamicAnchor": "dynamicTarget",
            "type": "integer",
        }
        schema["$defs"] = {
            "static": static_target,
            "dynamic": dynamic_target,
        }
        (
            eligible,
            static_anchors,
            dynamic_anchors,
        ) = checker.index_qinao_same_document_schema_targets(schema)

        self.assertEqual(
            checker.resolve_qinao_same_document_schema_reference(
                schema,
                "#staticTarget",
                eligible_schemas=eligible,
                static_anchors=static_anchors,
                dynamic_anchors=dynamic_anchors,
                reference_kind="static",
            ),
            (True, static_target),
        )
        self.assertEqual(
            checker.resolve_qinao_same_document_schema_reference(
                schema,
                "#dynamicTarget",
                eligible_schemas=eligible,
                static_anchors=static_anchors,
                dynamic_anchors=dynamic_anchors,
                reference_kind="dynamic",
            ),
            (True, dynamic_target),
        )
        self.assertEqual(
            checker.resolve_qinao_same_document_schema_reference(
                schema,
                "#dynamicTarget",
                eligible_schemas=eligible,
                static_anchors=static_anchors,
                dynamic_anchors=dynamic_anchors,
                reference_kind="static",
            ),
            (True, dynamic_target),
        )
        self.assertEqual(
            checker.resolve_qinao_same_document_schema_reference(
                schema,
                "#staticTarget",
                eligible_schemas=eligible,
                static_anchors=static_anchors,
                dynamic_anchors=dynamic_anchors,
                reference_kind="dynamic",
            ),
            (True, static_target),
        )

        instance_data = self.valid_draft202012_profile_schema()
        instance_data["const"] = {
            "$anchor": "notASchemaAnchor",
            "type": "string",
        }
        (
            instance_eligible,
            instance_static,
            instance_dynamic,
        ) = checker.index_qinao_same_document_schema_targets(instance_data)
        self.assertEqual(
            checker.resolve_qinao_same_document_schema_reference(
                instance_data,
                "#notASchemaAnchor",
                eligible_schemas=instance_eligible,
                static_anchors=instance_static,
                dynamic_anchors=instance_dynamic,
                reference_kind="static",
            ),
            (False, None),
        )

    def test_draft202012_profile_rejects_unresolved_local_pointer(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$ref"] = "#/$defs/missing"

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any("$ref target is unresolved" in error for error in errors),
            errors,
        )

    def test_draft202012_profile_rejects_pointer_into_instance_data(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["const"] = {"schemaLike": {"type": "string"}}
        schema["$ref"] = "#/const/schemaLike"

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any("$ref target is not an eligible schema" in error for error in errors),
            errors,
        )

    def test_draft202012_profile_distinguishes_missing_and_null_root_id(
        self,
    ) -> None:
        missing_identifier = self.valid_draft202012_profile_schema()
        del missing_identifier["$id"]
        self.assertEqual(
            checker.validate_qinao_draft202012_profile(missing_identifier),
            [],
        )

        null_identifier = self.valid_draft202012_profile_schema()
        null_identifier["$id"] = None
        errors = checker.validate_qinao_draft202012_profile(null_identifier)

        self.assertTrue(
            any("root $id is invalid" in error for error in errors),
            errors,
        )

    def test_draft202012_profile_rejects_semver_component_over_int32(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$id"] = "qinao://schemas/test-profile/2147483648.0.0"

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(any("root $id is invalid" in error for error in errors), errors)

    def test_draft202012_profile_rejects_4097_distinct_reference_edges(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$defs"] = {f"edge{index}": {"$ref": "#"} for index in range(4097)}

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any("distinct reference edges exceeds 4096" in error for error in errors),
            errors,
        )

    def test_draft202012_profile_enforces_anchor_name_and_class_rules(
        self,
    ) -> None:
        underscored = self.valid_draft202012_profile_schema()
        underscored["$anchor"] = "_ok"
        underscored["$ref"] = "#_ok"
        self.assertEqual(
            checker.validate_qinao_draft202012_profile(underscored),
            [],
        )

        bad_colon = self.valid_draft202012_profile_schema()
        bad_colon["$anchor"] = "bad:name"
        bad_colon_errors = checker.validate_qinao_draft202012_profile(bad_colon)
        self.assertTrue(
            any("$anchor is invalid" in error for error in bad_colon_errors),
            bad_colon_errors,
        )

        cross_class = self.valid_draft202012_profile_schema()
        cross_class["$anchor"] = "shared"
        cross_class["$dynamicAnchor"] = "shared"
        cross_class_errors = checker.validate_qinao_draft202012_profile(cross_class)
        self.assertTrue(
            any("anchor classes collide" in error for error in cross_class_errors),
            cross_class_errors,
        )

        for keyword in ("$anchor", "$dynamicAnchor"):
            with self.subTest(duplicate_keyword=keyword):
                duplicated = self.valid_draft202012_profile_schema()
                duplicated["$defs"] = {
                    "first": {keyword: "repeated"},
                    "second": {keyword: "repeated"},
                }
                duplicate_errors = checker.validate_qinao_draft202012_profile(
                    duplicated
                )
                self.assertTrue(
                    any("is duplicated" in error for error in duplicate_errors),
                    duplicate_errors,
                )

    def test_draft202012_profile_rejects_non_json_host_values_and_cycles(
        self,
    ) -> None:
        invalid_values = (
            b"bytes",
            {"set-member"},
            ("tuple",),
            object(),
            {1: "non-string key"},
            "\ud800",
            {"\ud800": "non-Unicode-scalar key"},
            {("k" * 1048577): "oversized key"},
        )
        for invalid in invalid_values:
            with self.subTest(invalid_type=type(invalid).__name__):
                schema = self.valid_draft202012_profile_schema()
                schema["const"] = invalid
                errors = checker.validate_qinao_draft202012_profile(schema)
                self.assertTrue(
                    any("JSON host model" in error for error in errors),
                    errors,
                )

        for invalid_float in (0.0, float("inf"), float("-inf"), float("nan")):
            with self.subTest(invalid_float=repr(invalid_float)):
                schema = self.valid_draft202012_profile_schema()
                schema["const"] = invalid_float
                errors = checker.validate_qinao_draft202012_profile(schema)
                self.assertTrue(
                    any(
                        "floating-point values are forbidden" in error
                        for error in errors
                    ),
                    errors,
                )

        cyclic: list[object] = []
        cyclic.append(cyclic)
        schema = self.valid_draft202012_profile_schema()
        schema["const"] = cyclic
        cycle_errors = checker.validate_qinao_draft202012_profile(schema)
        self.assertTrue(
            any("cyclic" in error for error in cycle_errors),
            cycle_errors,
        )

    def test_draft202012_profile_rejects_builtin_subclasses_without_dispatch(
        self,
    ) -> None:
        class HostileDict(dict):
            def get(self, *_args, **_kwargs):
                raise AssertionError("hostile dict method was invoked")

            def values(self):
                raise AssertionError("hostile dict method was invoked")

        class HostileList(list):
            def __iter__(self):
                raise AssertionError("hostile list method was invoked")

        class HostileString(str):
            def encode(self, *_args, **_kwargs):
                raise AssertionError("hostile string method was invoked")

        class HostileInt(int):
            pass

        hostile_root = HostileDict(self.valid_draft202012_profile_schema())
        root_errors = checker.validate_qinao_draft202012_profile(hostile_root)
        self.assertTrue(
            any("root must be an object" in error for error in root_errors),
            root_errors,
        )

        for invalid in (
            HostileDict({"value": 1}),
            HostileList([1]),
            HostileString("value"),
            HostileInt(1),
        ):
            with self.subTest(invalid_type=type(invalid).__name__):
                schema = self.valid_draft202012_profile_schema()
                schema["const"] = invalid
                errors = checker.validate_qinao_draft202012_profile(schema)
                self.assertTrue(
                    any("JSON host model" in error for error in errors),
                    errors,
                )

    def test_draft202012_profile_counts_distinct_anchor_ref_kinds_as_edges(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$anchor"] = "static"
        schema["$dynamicAnchor"] = "dynamic"
        schema["$ref"] = "#static"
        schema["$defs"] = {
            f"edge{index}": {
                "$ref": "#static",
                "$dynamicRef": "#dynamic",
            }
            for index in range(2048)
        }

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any("distinct reference edges exceeds 4096" in error for error in errors),
            errors,
        )

    def test_draft202012_profile_accepts_4096_distinct_anchor_ref_kind_edges(
        self,
    ) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$anchor"] = "static"
        schema["$dynamicAnchor"] = "dynamic"
        schema["$defs"] = {
            f"edge{index}": {
                "$ref": "#static",
                "$dynamicRef": "#dynamic",
            }
            for index in range(2048)
        }

        self.assertEqual(
            checker.validate_qinao_draft202012_profile(schema),
            [],
        )

    def test_draft202012_profile_rejects_4097_total_anchors(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$defs"] = {
            f"anchor{index}": {"$anchor": f"anchor{index}"} for index in range(4097)
        }

        errors = checker.validate_qinao_draft202012_profile(schema)

        self.assertTrue(
            any(
                "anchors plus dynamic anchors exceeds 4096" in error for error in errors
            ),
            errors,
        )

    def test_draft202012_profile_accepts_4096_edges_and_anchors(self) -> None:
        schema = self.valid_draft202012_profile_schema()
        schema["$defs"] = {
            f"edge{index}": {
                "$anchor": f"anchor{index}",
                "$ref": "#",
            }
            for index in range(4096)
        }

        self.assertEqual(
            checker.validate_qinao_draft202012_profile(schema),
            [],
        )

    @staticmethod
    def valid_draft202012_profile_schema() -> dict:
        return {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "$id": "qinao://schemas/test-profile/1.0.0",
            "type": "object",
            "properties": {
                "name": {"type": "string"},
            },
            "required": ["name"],
            "additionalProperties": False,
        }

    def test_ordered_wave_schedule_is_the_exact_frozen_authority(self) -> None:
        expected = (
            ("W0", "w0.gates", 1),
            ("W0", "w0.controlled", 2),
            ("W1", "w1.dual-space", 1),
            ("W2", "w2.persistence", 1),
            ("W3", "w3.state", 1),
            ("W3", "w3.context", 2),
            ("W4", "w4.model-execution", 1),
            ("W5", "w5.inspection-publication-apple", 1),
            ("W6", "w6.runtime.observation-values", 1),
            ("W6", "w6.semantic.audit-schema", 2),
            ("W6", "w6.runtime.audit-envelope-freeze", 3),
            ("W6", "w6.semantic.coordinator-behavior", 4),
            ("W6", "w6.runtime.integration-population", 5),
            ("W6", "w6.runtime.engine-cutover", 6),
            ("W6", "w6.apple-lab", 7),
            ("W6", "w6.certification", 8),
        )
        self.assertEqual(checker.ORDERED_WAVE_SCHEDULE, expected)
        self.assertEqual(len(expected), len(set(expected)))
        self.assertEqual(
            checker.ORDERED_WAVE_SCHEDULE_SHA256,
            hashlib.sha256(
                json.dumps(
                    expected,
                    ensure_ascii=False,
                    separators=(",", ":"),
                ).encode("utf-8")
            ).hexdigest(),
        )
        self.assertEqual(
            checker.validate_ordered_wave_schedule(expected),
            expected,
        )
        self.assertEqual(
            checker.WAVE_SCHEDULE,
            {
                (wave, wave_slice_id): sequence_ordinal
                for wave, wave_slice_id, sequence_ordinal in expected
            },
        )

    def test_schedule_source_mutations_fail_during_module_initialization(
        self,
    ) -> None:
        source_path = Path(checker.__file__).resolve()
        source = source_path.read_text(encoding="utf-8")
        state_row = '        ("W3", "w3.state", 1),\n'
        context_row = '        ("W3", "w3.context", 2),\n'
        mutations = {
            "duplicate ordinal": source.replace(
                '    ("W0", "w0.controlled", 2),\n',
                '    ("W0", "w0.controlled", 1),\n',
                1,
            ),
            "reordered rows": source.replace(
                state_row + context_row,
                context_row + state_row,
                1,
            ),
            "skipped row": source.replace(
                '    ("W2", "w2.persistence", 1),\n',
                "",
                1,
            ),
            "extra row": source.replace(
                '    ("W2", "w2.persistence", 1),\n',
                ('    ("W2", "w2.persistence", 1),\n    ("W2", "w2.extra", 2),\n'),
                1,
            ),
        }
        for label, mutated_source in mutations.items():
            with self.subTest(label=label):
                self.assertNotEqual(mutated_source, source)
                namespace = {
                    "__file__": str(source_path),
                    "__name__": f"test_schedule_mutation_{label}",
                }
                with self.assertRaisesRegex(
                    ValueError,
                    "ordered wave schedule",
                ):
                    exec(
                        compile(
                            mutated_source,
                            str(source_path),
                            "exec",
                        ),
                        namespace,
                    )

    def test_exact_slice_and_ordinal_arguments_are_mandatory(self) -> None:
        for option in ("--wave-slice-id", "--sequence-ordinal"):
            with self.subTest(option=option):
                command = self.command()
                index = command.index(option)
                del command[index : index + 2]
                result = self.run_gate(command)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("required", result.stderr)

    def test_mixed_valid_slices_within_one_wave_are_rejected(self) -> None:
        self.mutate_document(
            "create",
            lambda document: document.update(
                {
                    "waveSliceID": "w0.controlled",
                    "sequenceOrdinal": 2,
                }
            ),
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requested wave schedule tuple", result.stderr)

    def test_uniform_but_wrong_valid_slice_is_rejected(self) -> None:
        for category in self.documents:
            self.mutate_document(
                category,
                lambda document: document.update(
                    {
                        "waveSliceID": "w0.controlled",
                        "sequenceOrdinal": 2,
                    }
                ),
            )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("requested wave schedule tuple", result.stderr)

    def test_checker_main_captures_one_verification_time(self) -> None:
        class CountingDateTime(datetime):
            calls = 0

            @classmethod
            def now(cls, tz=None):
                cls.calls += 1
                return VERIFICATION_TIME

        command = self.command()
        with (
            mock.patch.object(
                checker,
                "datetime",
                CountingDateTime,
            ),
            mock.patch.object(
                sys,
                "argv",
                [str(SCRIPT), *command[2:]],
            ),
        ):
            self.assertEqual(checker.main(), 0)
        self.assertEqual(CountingDateTime.calls, 1)

    def test_missing_extension_category_argument_is_rejected(self) -> None:
        command = self.command()
        option_index = command.index("--extension-manifest-or-disposition")
        del command[option_index : option_index + 2]

        result = self.run_gate(command)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--extension-manifest-or-disposition", result.stderr)
        self.assertIn("required", result.stderr)

    def test_empty_adapter_category_document_is_rejected(self) -> None:
        command = self.command()
        option_index = command.index("--adapter-manifest-or-disposition")
        empty_path = self.directory / "empty-adapter.json"
        empty_path.write_bytes(b"")
        command[option_index + 1] = str(empty_path)

        result = self.run_gate(command)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("adapter category document is empty", result.stderr)

    def test_duplicate_candidate_rows_are_rejected(self) -> None:
        row = {
            "path": "BehavioralAISubstrate/Sources/BASRuntimeCore/Existing.swift",
            "blob": "b" * 40,
            "change": "modify",
            "ownerID": "identity.semantic-layers",
            "classification": "E",
            "symbol": "BASCognitiveLayer",
            "authorityClaims": [],
        }
        self.documents["extension"] = self.category_document(
            "extension",
            status="present",
            rows=[row, copy.deepcopy(row)],
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("duplicate", result.stderr)
        self.assertIn("reviewedRows", result.stderr)

    def test_extra_manifest_row_absent_from_production_diff_is_rejected(self) -> None:
        self.documents["extension"] = self.category_document(
            "extension",
            status="present",
            rows=[
                {
                    "path": (
                        "BehavioralAISubstrate/Sources/BASRuntimeCore/"
                        "BASObservationReconciliationCore.swift"
                    ),
                    "blob": "b" * 40,
                    "change": "modify",
                    "ownerID": "identity.semantic-layers",
                    "classification": "E",
                    "symbol": "BASCognitiveLayer",
                    "authorityClaims": [],
                }
            ],
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("extra", result.stderr)
        self.assertIn("production diff", result.stderr)

    def test_cross_wave_category_reuse_is_rejected(self) -> None:
        self.mutate_document(
            "fixture",
            lambda document: document.__setitem__("wave", "W1"),
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture cross-wave reuse", result.stderr)

    def test_stale_base_and_diff_roots_are_rejected(self) -> None:
        self.mutate_document(
            "create",
            lambda document: (
                document.__setitem__("baseTree", "0" * 40),
                document.__setitem__("productionDiffRoot", "f" * 64),
            ),
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("baseTree", result.stderr)
        self.assertIn("productionDiffRoot", result.stderr)

    def test_invalid_category_signature_is_rejected(self) -> None:
        self.documents["adapter"]["signature"] = base64.b64encode(b"\0" * 64).decode(
            "ascii"
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("signature", result.stderr)
        self.assertIn("adapter", result.stderr)

    def test_unknown_extension_owner_and_path_are_rejected(self) -> None:
        path = "BehavioralAISubstrate/Sources/BASRuntimeCore/UnknownExtension.swift"
        row = {
            "path": path,
            "blob": "e" * 40,
            "change": "add",
            "ownerID": "unknown.owner",
            "classification": "E",
            "symbol": "UnknownExtension",
            "authorityClaims": [],
        }
        diff_root = hashlib.sha256(_canonical_test_json([row])).hexdigest()
        self.empty_diff_root = diff_root
        self.documents["extension"] = self.category_document(
            "extension",
            status="present",
            rows=[row],
        )

        self.assertTrue(
            hasattr(checker, "validate_category_evidence"),
            "the authority gate needs per-category semantic validation",
        )
        with LEDGER.open("r", encoding="utf-8") as handle:
            ledger = json.load(handle)
        errors = checker.validate_category_evidence(
            self.documents["extension"],
            category="extension",
            wave="W0",
            wave_slice_id="w0.gates",
            sequence_ordinal=1,
            base_tree=self.base_tree,
            production_diff_root=diff_root,
            derived_rows=[row],
            ledger=ledger,
            root=ROOT,
            candidate_tree=self.candidate_tree,
            trust_root=self.trust_root,
            verification_time=VERIFICATION_TIME,
        )

        self.assertTrue(any("unknown.owner" in error for error in errors), errors)
        self.assertTrue(any("unknown" in error.lower() for error in errors), errors)
        self.assertTrue(any(path in error for error in errors), errors)

    def test_adapter_cannot_claim_writer_or_effect_authority(self) -> None:
        self.documents["adapter"] = self.category_document(
            "adapter",
            status="present",
            rows=[
                {
                    "path": (
                        "QinaoRuntimeSDK/Sources/QinaoLoop/QinaoOrganEndpoint.swift"
                    ),
                    "blob": "c" * 40,
                    "change": "modify",
                    "ownerID": "provider.package-boundary",
                    "classification": "A",
                    "symbol": "QinaoOrganEndpoint",
                    "authorityClaims": ["writer", "externalEffect"],
                }
            ],
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("adapter", result.stderr)
        self.assertIn("writer", result.stderr)
        self.assertIn("effect", result.stderr.lower())

    def test_e_candidate_cannot_be_passed_through_create_gate(self) -> None:
        self.documents["create"] = self.category_document(
            "create",
            status="present",
            rows=[
                {
                    "path": (
                        "BehavioralAISubstrate/Sources/BASRuntimeCore/"
                        "BASObservationReconciliationCore.swift"
                    ),
                    "blob": "d" * 40,
                    "change": "modify",
                    "ownerID": "identity.semantic-layers",
                    "classification": "E",
                    "symbol": "BASCognitiveLayer",
                    "authorityClaims": [],
                }
            ],
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("create", result.stderr)
        self.assertIn("classification", result.stderr)
        self.assertIn("M", result.stderr)

    def test_first_wire_for_missing_m_owner_cannot_have_zero_create_rows(self) -> None:
        with LEDGER.open("r", encoding="utf-8") as handle:
            ledger = json.load(handle)
        permission = next(
            row
            for row in ledger["create_permissions"]
            if not (ROOT / row["allowed_paths"][0]).is_file()
        )
        path = permission["allowed_paths"][0]
        row = {
            "path": path,
            "blob": "e" * 40,
            "change": "add",
            "ownerID": permission["owner_id"],
            "classification": "M",
            "symbol": permission["authority_symbol"],
            "authorityClaims": [],
        }
        diff_root = hashlib.sha256(_canonical_test_json([row])).hexdigest()

        self.assertTrue(
            hasattr(checker, "validate_category_evidence"),
            "the authority gate needs per-category semantic validation",
        )
        errors = checker.validate_category_evidence(
            self.documents["create"],
            category="create",
            wave="W0",
            wave_slice_id="w0.gates",
            sequence_ordinal=1,
            base_tree=self.base_tree,
            production_diff_root=diff_root,
            derived_rows=[row],
            ledger=ledger,
            root=ROOT,
            candidate_tree=self.candidate_tree,
            trust_root=self.trust_root,
            verification_time=VERIFICATION_TIME,
        )

        self.assertTrue(
            any(permission["owner_id"] in error for error in errors),
            errors,
        )
        self.assertTrue(any("create" in error for error in errors), errors)
        self.assertTrue(any("zero" in error for error in errors), errors)

    def test_missing_anchor_and_empty_glob_are_rejected(self) -> None:
        self.documents["fixture"] = self.category_document(
            "fixture",
            anchors=[
                {
                    "path": ("BehavioralAISubstrate/Tests/DefinitelyMissing.swift"),
                    "blob": "a" * 40,
                },
                {
                    "path": "BehavioralAISubstrate/Tests/NoSuchSuite.swift",
                    "blob": "b" * 40,
                },
            ],
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DefinitelyMissing.swift", result.stderr)
        self.assertIn("NoSuchSuite.swift", result.stderr)
        self.assertIn("anchor", result.stderr)

    def test_anchor_tool_errors_cannot_be_reported_as_no_match(self) -> None:
        self.assertTrue(
            hasattr(checker, "resolve_anchor_paths"),
            "the authority gate needs a fail-closed anchor resolver",
        )
        with mock.patch.object(
            checker,
            "run_bounded_process",
            side_effect=subprocess.TimeoutExpired(["git", "ls-tree"], 30),
        ):
            _paths, errors = checker.resolve_anchor_paths(
                ROOT,
                self.candidate_tree,
                [
                    {
                        "path": "BehavioralAISubstrate/Tests/Example.swift",
                        "blob": "a" * 40,
                    }
                ],
            )
        self.assertTrue(any("tool error" in error for error in errors), errors)

    def test_anchors_are_resolved_only_from_candidate_tree(self) -> None:
        repository = self.directory / "anchor-repository"
        repository.mkdir()
        subprocess.run(
            ["git", "init", "-q"],
            cwd=repository,
            check=True,
        )
        (repository / "README.md").write_text("anchor fixture\n", encoding="utf-8")
        subprocess.run(
            ["git", "add", "README.md"],
            cwd=repository,
            check=True,
        )
        base_tree = subprocess.run(
            ["git", "write-tree"],
            cwd=repository,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        candidate_only_path = "docs/test-only-candidate-anchor.txt"
        object_id = (
            subprocess.run(
                ["git", "hash-object", "-w", "--stdin"],
                cwd=repository,
                input=b"candidate-only anchor\n",
                check=True,
                capture_output=True,
            )
            .stdout.decode("ascii")
            .strip()
        )
        subprocess.run(
            [
                "git",
                "update-index",
                "--add",
                "--cacheinfo",
                f"100644,{object_id},{candidate_only_path}",
            ],
            cwd=repository,
            check=True,
        )
        candidate_tree = subprocess.run(
            ["git", "write-tree"],
            cwd=repository,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.assertNotEqual(candidate_tree, base_tree)

        resolved, errors = checker.resolve_anchor_paths(
            repository,
            candidate_tree,
            [{"path": candidate_only_path, "blob": object_id}],
        )

        self.assertEqual(errors, [])
        self.assertEqual(resolved, [candidate_only_path])
        self.assertFalse((repository / candidate_only_path).exists())

        live_only_path = repository / "test-only-live-anchor.txt"
        live_only_path.write_text("live-only anchor\n", encoding="utf-8")
        resolved, errors = checker.resolve_anchor_paths(
            repository,
            candidate_tree,
            [
                {
                    "path": live_only_path.relative_to(repository).as_posix(),
                    "blob": object_id,
                }
            ],
        )

        self.assertEqual(resolved, [])
        self.assertTrue(
            any("missing anchored candidate-tree blob" in error for error in errors)
        )

    def test_forbidden_second_automation_authority_is_rejected(self) -> None:
        path = "BehavioralAISubstrate/Sources/BASRuntimeCore/AutomationStore.swift"
        self.assertTrue(
            hasattr(checker, "validate_swift_authority_source"),
            "the authority gate needs a candidate-tree Swift authority scanner",
        )
        errors = checker.validate_swift_authority_source(
            path,
            "public actor AutomationStore {}\n",
        )

        self.assertTrue(any("AutomationStore" in error for error in errors), errors)
        self.assertTrue(any("second" in error for error in errors), errors)

    def test_exact_apple_effect_adapter_path_is_allowed(self) -> None:
        errors = checker.validate_swift_authority_source(
            (
                "BehavioralAISubstrate/Sources/BASAppleEdgeWiring/"
                "BASToolEffectAdapter.swift"
            ),
            (
                "import EventKit\n"
                "func mutate(_ store: EKEventStore, _ event: EKEvent) throws {\n"
                "  try store.save(event, span: .thisEvent)\n"
                "}\n"
            ),
        )

        self.assertEqual(errors, [])

    def test_apple_effect_adapter_path_near_misses_are_rejected(self) -> None:
        near_miss_paths = (
            (
                "BehavioralAISubstrate/Sources/BASAppleEdgeWiring/"
                "BASToolEffectAdapterCopy.swift"
            ),
            (
                "BehavioralAISubstrate/Sources/BASRuntimeCore/"
                "BASToolEffectAdapter.swift"
            ),
            (
                "BehavioralAISubstrate/Sources/BASAppleEdgeWiring/../"
                "BASAppleEdgeWiring/BASToolEffectAdapter.swift"
            ),
            (
                "BehavioralAISubstrate/Sources/BASAppleEdgeWiring/"
                "ZoneCAppleEffectExecutor.swift"
            ),
        )
        source = (
            "import EventKit\n"
            "func mutate(_ store: EKEventStore, _ event: EKEvent) throws {\n"
            "  try store.save(event, span: .thisEvent)\n"
            "}\n"
        )

        for path in near_miss_paths:
            with self.subTest(path=path):
                errors = checker.validate_swift_authority_source(path, source)
                self.assertTrue(
                    any("direct Apple mutation" in error for error in errors),
                    errors,
                )

    def test_direct_apple_mutation_outside_effect_adapter_is_rejected(self) -> None:
        path = "BehavioralAISubstrate/Sources/BASRuntimeCore/UnsafeCalendar.swift"
        self.assertTrue(
            hasattr(checker, "validate_swift_authority_source"),
            "the authority gate needs a candidate-tree Swift authority scanner",
        )
        errors = checker.validate_swift_authority_source(
            path,
            (
                "import EventKit\n"
                "func mutate(_ store: EKEventStore, _ event: EKEvent) throws {\n"
                "  try store.save(event, span: .thisEvent)\n"
                "}\n"
            ),
        )

        self.assertTrue(
            any("UnsafeCalendar.swift" in error for error in errors), errors
        )
        self.assertTrue(
            any("BASToolEffectAdapter.swift" in error for error in errors),
            errors,
        )

    def test_core_spotlight_mutation_selectors_are_rejected(self) -> None:
        selectors = (
            "index.indexSearchableItems([])",
            "index.deleteSearchableItems(withIdentifiers: [])",
            "index.deleteAllSearchableItems()",
        )

        for selector in selectors:
            with self.subTest(selector=selector):
                errors = checker.validate_swift_authority_source(
                    "BehavioralAISubstrate/Sources/BASRuntimeCore/UnsafeIndex.swift",
                    (
                        "import CoreSpotlight\n"
                        "func mutate(_ index: CSSearchableIndex) async throws {\n"
                        f"  try await {selector}\n"
                        "}\n"
                    ),
                )
                self.assertTrue(
                    any("direct Apple mutation" in error for error in errors),
                    errors,
                )

    def test_notification_removal_selectors_are_rejected(self) -> None:
        selectors = (
            "center.removePendingNotificationRequests(withIdentifiers: [])",
            "center.removeDeliveredNotifications(withIdentifiers: [])",
            "center.removeAllPendingNotificationRequests()",
            "center.removeAllDeliveredNotifications()",
        )

        for selector in selectors:
            with self.subTest(selector=selector):
                errors = checker.validate_swift_authority_source(
                    (
                        "BehavioralAISubstrate/Sources/BASRuntimeCore/"
                        "UnsafeNotification.swift"
                    ),
                    (
                        "import UserNotifications\n"
                        "func mutate(_ center: UNUserNotificationCenter) {\n"
                        f"  {selector}\n"
                        "}\n"
                    ),
                )
                self.assertTrue(
                    any("direct Apple mutation" in error for error in errors),
                    errors,
                )

    def test_cloudkit_sync_engine_send_and_fetch_are_rejected(self) -> None:
        selectors = (
            "engine.sendChanges()",
            "engine.fetchChanges()",
        )

        for selector in selectors:
            with self.subTest(selector=selector):
                errors = checker.validate_swift_authority_source(
                    "BehavioralAISubstrate/Sources/BASRuntimeCore/UnsafeSync.swift",
                    (
                        "import CloudKit\n"
                        "func mutate(_ engine: CKSyncEngine) async throws {\n"
                        f"  try await {selector}\n"
                        "}\n"
                    ),
                )
                self.assertTrue(
                    any("direct Apple mutation" in error for error in errors),
                    errors,
                )

    def test_attributed_and_specific_apple_imports_are_gated(self) -> None:
        fixtures = (
            (
                "EventKit",
                (
                    "@preconcurrency import class EventKit.EKEventStore\n"
                    "func mutate(_ store: EKEventStore, _ event: EKEvent) throws {\n"
                    "  try store.save(event, span: .thisEvent)\n"
                    "}\n"
                ),
            ),
            (
                "CoreSpotlight",
                (
                    "@_implementationOnly import class "
                    "CoreSpotlight.CSSearchableIndex\n"
                    "func mutate(_ index: CSSearchableIndex) async throws {\n"
                    "  try await index.indexSearchableItems([])\n"
                    "}\n"
                ),
            ),
            (
                "CloudKit",
                (
                    "@_spi(Qinao) @preconcurrency "
                    "import struct CloudKit.CKSyncEngine;\n"
                    "func mutate(_ engine: CKSyncEngine) async throws {\n"
                    "  try await engine.sendChanges()\n"
                    "}\n"
                ),
            ),
            (
                "UserNotifications",
                (
                    "@_spi(Qinao)\n"
                    "@preconcurrency\n"
                    "import class "
                    "UserNotifications.UNUserNotificationCenter\n"
                    "func mutate(_ center: UNUserNotificationCenter) {\n"
                    "  center.removeAllDeliveredNotifications()\n"
                    "}\n"
                ),
            ),
        )

        for framework, source in fixtures:
            with self.subTest(framework=framework):
                errors = checker.validate_swift_authority_source(
                    (
                        "BehavioralAISubstrate/Sources/BASRuntimeCore/"
                        f"Unsafe{framework}Import.swift"
                    ),
                    source,
                )
                self.assertTrue(
                    any("direct Apple mutation" in error for error in errors),
                    errors,
                )

    def test_all_swift_specific_import_kinds_are_gated(self) -> None:
        import_kinds = (
            "class",
            "struct",
            "enum",
            "protocol",
            "func",
            "var",
            "let",
            "typealias",
        )

        for import_kind in import_kinds:
            with self.subTest(import_kind=import_kind):
                errors = checker.validate_swift_authority_source(
                    "BehavioralAISubstrate/Sources/BASRuntimeCore/UnsafeImport.swift",
                    (
                        f"import {import_kind} EventKit.ImportedSymbol\n"
                        "func mutate(_ store: EKEventStore, _ event: EKEvent) throws {\n"
                        "  try store.save(event, span: .thisEvent)\n"
                        "}\n"
                    ),
                )
                self.assertTrue(
                    any("direct Apple mutation" in error for error in errors),
                    errors,
                )

    def test_swift_access_level_imports_are_gated(self) -> None:
        imports = (
            "public import EventKit",
            "package import EventKit",
            "@preconcurrency internal import class EventKit.EKEventStore",
            "fileprivate import EventKit.Calendar",
            "@_spi(Qinao) private import struct EventKit.ImportedSymbol;",
        )

        for import_declaration in imports:
            with self.subTest(import_declaration=import_declaration):
                errors = checker.validate_swift_authority_source(
                    "BehavioralAISubstrate/Sources/BASRuntimeCore/UnsafeImport.swift",
                    (
                        f"{import_declaration}\n"
                        "func mutate(_ store: EKEventStore, _ event: EKEvent) throws {\n"
                        "  try store.save(event, span: .thisEvent)\n"
                        "}\n"
                    ),
                )
                self.assertTrue(
                    any("direct Apple mutation" in error for error in errors),
                    errors,
                )

    def test_open_is_not_accepted_as_a_swift_import_access_level(self) -> None:
        errors = checker.validate_swift_authority_source(
            "BehavioralAISubstrate/Sources/BASRuntimeCore/InvalidImport.swift",
            (
                "open import EventKit\n"
                "func mutate(_ store: Store, _ event: Event) throws {\n"
                "  try store.save(event)\n"
                "}\n"
            ),
        )

        self.assertEqual(errors, [])

    def test_submodule_import_with_trailing_semicolon_is_gated(self) -> None:
        errors = checker.validate_swift_authority_source(
            "BehavioralAISubstrate/Sources/BASRuntimeCore/UnsafeSubmodule.swift",
            (
                "import EventKit.Calendar.Submodule; "
                "func mutate(_ store: EKEventStore, _ event: EKEvent) throws { "
                "try store.save(event, span: .thisEvent) }\n"
            ),
        )

        self.assertTrue(
            any("direct Apple mutation" in error for error in errors),
            errors,
        )

    def test_apple_import_parser_ignores_free_text_and_similar_modules(
        self,
    ) -> None:
        errors = checker.validate_swift_authority_source(
            "BehavioralAISubstrate/Sources/BASRuntimeCore/EventKitUIHelper.swift",
            (
                "import EventKitUI\n"
                "let help = \"@preconcurrency import class EventKit.EKEventStore;\"\n"
                "// @_spi(Qinao) import EventKit\n"
                "/* import class EventKit.EKEventStore; */\n"
                "func mutate(_ store: Store, _ event: Event) throws {\n"
                "  try store.save(event)\n"
                "}\n"
            ),
        )

        self.assertEqual(errors, [])

    def test_apple_mutation_scanner_ignores_comments_and_string_literals(
        self,
    ) -> None:
        errors = checker.validate_swift_authority_source(
            "BehavioralAISubstrate/Sources/BASRuntimeCore/AppleHelpText.swift",
            (
                "import EventKit\n"
                "let help = \"store.save(event, span: .thisEvent)\"\n"
                "// store.save(event, span: .thisEvent)\n"
                "/* store.remove(event, span: .thisEvent) */\n"
            ),
        )

        self.assertEqual(errors, [])

    def test_apple_mutation_selectors_are_scoped_to_imported_framework(
        self,
    ) -> None:
        fixtures = (
            (
                "import UserNotifications\n"
                "func update(_ values: inout [String]) { values.remove(at: 0) }\n"
            ),
            (
                "import CoreSpotlight\n"
                "func update(_ cache: Cache) throws { try cache.save() }\n"
            ),
            (
                "import EventKit\n"
                "func update(_ index: Index) { index.deleteAllSearchableItems() }\n"
            ),
        )

        for source in fixtures:
            with self.subTest(source=source):
                errors = checker.validate_swift_authority_source(
                    "BehavioralAISubstrate/Sources/BASRuntimeCore/Helper.swift",
                    source,
                )
                self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
