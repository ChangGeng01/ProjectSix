import copy
import base64
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Callable
from unittest import mock

try:
    from scripts import check_qinao_owner_ledger as checker
except ModuleNotFoundError:  # Direct `python scripts/test_...py` invocation.
    import check_qinao_owner_ledger as checker


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_qinao_owner_ledger.py"
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
        checker_source: str = "print('read-only audit gate')\n",
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
        checker_path.write_text(checker_source, encoding="utf-8")
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
            item
            for item in data["create_permissions"]
            if item["owner_id"] == owner_id
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
            "match": "match 0:\n    case print:\n        pass\n",
            "delete": "del print\n",
            "qualified-root": (
                "from pathlib import Path\nfor str in [Path]:\n    pass\n"
            ),
        }
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
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _make_default_wave_arguments(directory: Path) -> list[str]:
    def git(*arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def signed(value: dict) -> dict:
        result = copy.deepcopy(value)
        result["signature"] = base64.b64encode(
            _test_ed25519_sign(
                QinaoWaveAuthorityGateTests.TEST_SEED,
                _canonical_test_json(value),
            )
        ).decode("ascii")
        return result

    def write(name: str, value: object) -> Path:
        path = directory / name
        path.write_bytes(_canonical_test_json(value) + b"\n")
        return path

    base_tree = git("rev-parse", "HEAD^{tree}")
    public_key, _prefix, _scalar = _test_ed25519_key(
        QinaoWaveAuthorityGateTests.TEST_SEED
    )
    trust_root = {
        "schema": "QinaoAdmissionTrustRootV1",
        "repositoryIdentity": QinaoWaveAuthorityGateTests.REPOSITORY_IDENTITY,
        "issuedAt": QinaoWaveAuthorityGateTests.ISSUED_AT,
        "expiresAt": QinaoWaveAuthorityGateTests.EXPIRES_AT,
        "keys": [
            {
                "keyID": QinaoWaveAuthorityGateTests.TEST_KEY_ID,
                "role": role,
                "publicKey": base64.b64encode(public_key).decode("ascii"),
            }
            for role in ("source-selector", "wave-category-reviewer")
        ],
        "revokedNonces": [],
    }
    design_digest = hashlib.sha256(
        QinaoWaveAuthorityGateTests.DESIGN_PATH.read_bytes()
    ).hexdigest()
    source_selection = signed(
        {
            "schema": "QinaoSourceSelectionV1",
            "repositoryIdentity": QinaoWaveAuthorityGateTests.REPOSITORY_IDENTITY,
            "selectedCommit": git("rev-parse", "HEAD"),
            "selectedTree": base_tree,
            "approvedDesignBlob": design_digest,
            "externalVerifierSHA256": "a" * 64,
            "issuedAt": QinaoWaveAuthorityGateTests.ISSUED_AT,
            "expiresAt": QinaoWaveAuthorityGateTests.EXPIRES_AT,
            "nonce": "legacy-source-selection-test-nonce",
            "signer": QinaoWaveAuthorityGateTests.TEST_KEY_ID,
            "role": "source-selector",
            "signatureAlgorithm": "Ed25519",
        }
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
                    "category": category,
                    "status": "notApplicable",
                    "baseTree": base_tree,
                    "approvedDesignBlob": design_digest,
                    "productionDiffRoot": empty_diff_root,
                    "reviewedRows": [],
                    "anchors": [],
                    "reason": "legacy checker tests carry no production tree diff",
                    "issuedAt": QinaoWaveAuthorityGateTests.ISSUED_AT,
                    "expiresAt": QinaoWaveAuthorityGateTests.EXPIRES_AT,
                    "nonce": f"legacy-{category}-test-nonce",
                    "signer": QinaoWaveAuthorityGateTests.TEST_KEY_ID,
                    "role": "wave-category-reviewer",
                    "signatureAlgorithm": "Ed25519",
                }
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
        "--create-manifest-or-disposition",
        str(categories["create"]),
        "--extension-manifest-or-disposition",
        str(categories["extension"]),
        "--adapter-manifest-or-disposition",
        str(categories["adapter"]),
        "--fixture-set-or-disposition",
        str(categories["fixture"]),
    ]


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
    TEST_SEED = bytes(range(32))
    TEST_KEY_ID = "test-wave-review-key"
    ISSUED_AT = "2026-07-29T00:00:00Z"
    EXPIRES_AT = "2030-01-01T00:00:00Z"

    def setUp(self) -> None:
        self.temp_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_directory.cleanup)
        self.directory = Path(self.temp_directory.name)
        self.base_tree = self.git("rev-parse", "HEAD^{tree}")
        self.candidate_tree = self.base_tree
        self.design_digest = hashlib.sha256(self.DESIGN_PATH.read_bytes()).hexdigest()
        self.empty_diff_root = hashlib.sha256(_canonical_test_json([])).hexdigest()
        public_key, _prefix, _scalar = _test_ed25519_key(self.TEST_SEED)
        self.trust_root = {
            "schema": "QinaoAdmissionTrustRootV1",
            "repositoryIdentity": self.REPOSITORY_IDENTITY,
            "issuedAt": self.ISSUED_AT,
            "expiresAt": self.EXPIRES_AT,
            "keys": [
                {
                    "keyID": self.TEST_KEY_ID,
                    "role": "wave-category-reviewer",
                    "publicKey": base64.b64encode(public_key).decode("ascii"),
                },
                {
                    "keyID": self.TEST_KEY_ID,
                    "role": "source-selector",
                    "publicKey": base64.b64encode(public_key).decode("ascii"),
                },
            ],
            "revokedNonces": [],
        }
        self.source_selection = self.signed(
            {
                "schema": "QinaoSourceSelectionV1",
                "repositoryIdentity": self.REPOSITORY_IDENTITY,
                "selectedCommit": self.git("rev-parse", "HEAD"),
                "selectedTree": self.base_tree,
                "approvedDesignBlob": self.design_digest,
                "externalVerifierSHA256": "a" * 64,
                "issuedAt": self.ISSUED_AT,
                "expiresAt": self.EXPIRES_AT,
                "nonce": "source-selection-test-nonce",
                "signer": self.TEST_KEY_ID,
                "role": "source-selector",
                "signatureAlgorithm": "Ed25519",
            }
        )
        self.documents: dict[str, dict] = {
            category: self.category_document(category)
            for category in ("create", "extension", "adapter", "fixture")
        }

    @staticmethod
    def git(*arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def signed(self, value: dict) -> dict:
        signed = copy.deepcopy(value)
        signed["signature"] = base64.b64encode(
            _test_ed25519_sign(self.TEST_SEED, _canonical_test_json(value))
        ).decode("ascii")
        return signed

    def category_document(
        self,
        category: str,
        *,
        status: str = "notApplicable",
        rows: list[dict] | None = None,
        anchors: list[str] | None = None,
    ) -> dict:
        rows = [] if rows is None else rows
        return self.signed(
            {
                "schema": "QinaoWaveCategoryEvidenceV1",
                "repositoryIdentity": self.REPOSITORY_IDENTITY,
                "wave": "W0",
                "category": category,
                "status": status,
                "baseTree": self.base_tree,
                "approvedDesignBlob": self.design_digest,
                "productionDiffRoot": self.empty_diff_root,
                "reviewedRows": rows,
                "anchors": [] if anchors is None else anchors,
                "reason": (
                    "W0 changes governance and floor tooling only"
                    if status == "notApplicable"
                    else None
                ),
                "issuedAt": self.ISSUED_AT,
                "expiresAt": self.EXPIRES_AT,
                "nonce": f"{category}-test-nonce",
                "signer": self.TEST_KEY_ID,
                "role": "wave-category-reviewer",
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
            str(ROOT),
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
            "--create-manifest-or-disposition",
            str(paths["create"]),
            "--extension-manifest-or-disposition",
            str(paths["extension"]),
            "--adapter-manifest-or-disposition",
            str(paths["adapter"]),
            "--fixture-set-or-disposition",
            str(paths["fixture"]),
        ]

    def run_gate(self, command: list[str] | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            self.command() if command is None else command,
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )

    def mutate_document(self, category: str, mutation: Callable[[dict], None]) -> None:
        document = copy.deepcopy(self.documents[category])
        document.pop("signature")
        mutation(document)
        self.documents[category] = self.signed(document)

    def candidate_tree_with_blob(self, path: str, contents: bytes) -> str:
        object_id = subprocess.run(
            ["git", "hash-object", "-w", "--stdin"],
            cwd=ROOT,
            input=contents,
            check=True,
            capture_output=True,
        ).stdout.decode("ascii").strip()
        index = self.directory / "index"
        environment = dict(os.environ)
        environment["GIT_INDEX_FILE"] = str(index)
        subprocess.run(
            ["git", "read-tree", self.base_tree],
            cwd=ROOT,
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
            cwd=ROOT,
            env=environment,
            check=True,
        )
        return subprocess.run(
            ["git", "write-tree"],
            cwd=ROOT,
            env=environment,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def test_all_required_wave_arguments_are_accepted_and_valid_w0_passes(self) -> None:
        result = self.run_gate()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("create=0", result.stdout)
        self.assertIn("extension=0", result.stdout)
        self.assertIn("adapter=0", result.stdout)
        self.assertIn("fixture=0", result.stdout)

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
            base_tree=self.base_tree,
            production_diff_root=diff_root,
            derived_rows=[row],
            ledger=ledger,
            root=ROOT,
            trust_root=self.trust_root,
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
                        "QinaoRuntimeSDK/Sources/QinaoLoop/"
                        "QinaoOrganEndpoint.swift"
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
            base_tree=self.base_tree,
            production_diff_root=diff_root,
            derived_rows=[row],
            ledger=ledger,
            root=ROOT,
            trust_root=self.trust_root,
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
                "BehavioralAISubstrate/Tests/DefinitelyMissing.swift",
                "BehavioralAISubstrate/Tests/NoSuchSuite*.swift",
            ],
        )

        result = self.run_gate()

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("DefinitelyMissing.swift", result.stderr)
        self.assertIn("NoSuchSuite*.swift", result.stderr)
        self.assertIn("anchor", result.stderr)

    def test_anchor_tool_errors_cannot_be_reported_as_no_match(self) -> None:
        self.assertTrue(
            hasattr(checker, "resolve_anchor_paths"),
            "the authority gate needs a fail-closed anchor resolver",
        )
        with mock.patch.object(Path, "glob", side_effect=OSError("scanner failed")):
            _paths, errors = checker.resolve_anchor_paths(
                ROOT,
                ["BehavioralAISubstrate/Tests/*.swift"],
            )
        self.assertTrue(any("tool error" in error for error in errors), errors)

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

    def test_direct_apple_mutation_outside_zone_c_is_rejected(self) -> None:
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

        self.assertTrue(any("UnsafeCalendar.swift" in error for error in errors), errors)
        self.assertTrue(
            any("ZoneCAppleEffectExecutor" in error for error in errors),
            errors,
        )


if __name__ == "__main__":
    unittest.main()
