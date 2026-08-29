#!/usr/bin/env python3
"""Adversarial tests for the Qinao convergence audit kernel.

The first three classes are deliberately runnable by the one pre-ledger
bootstrap interpreter exception.  They use the standard library only and
never open a network transport.
"""

from __future__ import annotations

import base64
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


AUDIT_PATH = Path(__file__).with_name("qinao_convergence_audit.py")
ERRATUM_DIGEST = "ad01e833fef13bb68e2d536d9774a005d9bf30b6987b0215caad954527ba737b"
EXPECTED_TREE = "3a1674651a95e91b321b637b801db66d71e6fafb"
EXACT_PROBES = ("probe.gV8vVx", "probe.9erZU8", "probe.U4rXSq")


def _load_audit_module():
    if not AUDIT_PATH.is_file():
        return None
    spec = importlib.util.spec_from_file_location("qinao_convergence_audit", AUDIT_PATH)
    if spec is None or spec.loader is None:
        return None
    loaded = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = loaded
    spec.loader.exec_module(loaded)
    return loaded


module = _load_audit_module()


class _ModuleRequired(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(
            module,
            "qinao_convergence_audit.py is intentionally absent during RED",
        )


def _mode(path: Path) -> int:
    return stat.S_IMODE(path.lstat().st_mode)


def _mkdir(path: Path, mode: int = 0o700) -> None:
    path.mkdir(mode=mode)
    os.chmod(path, mode)


def _new_run_root(parent: Path) -> Path:
    root = parent / "run"
    _mkdir(root)
    _mkdir(root / "home")
    _mkdir(root / "tmp")
    _mkdir(root / "bootstrap")
    return root


def _identity_fields(repository: Path) -> dict:
    return {
        "branch": "refs/heads/codex/qinao-git-only-convergence",
        "repository": str(repository.resolve()),
        "S": "f" * 40,
        "D": "d" * 40,
        "C": "c" * 40,
        "C_TREE": EXPECTED_TREE,
        "configDigest": "4" * 64,
        "erratumDigest": ERRATUM_DIGEST,
        "schemaVersion": "qinao.run-identity.v1",
    }


def _write_exact_probe(bootstrap: Path, name: str) -> None:
    probe = bootstrap / name
    _mkdir(probe, 0o700)
    _mkdir(probe / "objects", 0o755)


def _write_n34_generation(bootstrap: Path, *, erratum_digest: str = ERRATUM_DIGEST) -> None:
    generation = bootstrap / "tree-prediction.N34crC"
    _mkdir(generation)
    _mkdir(generation / "objects")
    shared = b"objects/aa/bb\x00100644\x001\x00" + b"0" * 64 + b"\x00"
    (generation / "shared-objects.before.bin").write_bytes(shared)
    (generation / "shared-objects.after.bin").write_bytes(shared)
    shared_digest = hashlib.sha256(shared).hexdigest()
    proof = (
        "C=" + "c" * 40 + "\n"
        "predicted_tree=" + EXPECTED_TREE + "\n"
        "shared_objects_before_sha256=" + shared_digest + "\n"
        "shared_objects_after_sha256=" + shared_digest + "\n"
        "isolated_regular_file_count=0\n"
        "closure_missing_count=0\n"
        "controller_erratum_sha256=" + erratum_digest + "\n"
    ).encode("ascii")
    result = (
        "predicted_tree=" + EXPECTED_TREE + "\n"
        "shared_objects_before=" + shared_digest + "\n"
    ).encode("ascii")
    (generation / "alternate-reuse-proof.tsv").write_bytes(proof)
    (generation / "result.tsv").write_bytes(result)
    for path in generation.iterdir():
        if path.is_file():
            os.chmod(path, 0o600)


class SterilePythonLauncherTests(_ModuleRequired):
    """Breaks caught: inherited code/import/TLS state reaches target execution."""

    def _invoke(self, root: Path, repository: Path, *, outer_env_i: bool, extra_env=None):
        command = []
        if outer_env_i:
            command.extend(
                [
                    "/usr/bin/env",
                    "-i",
                    "HOME=" + str(root / "home"),
                    "TMPDIR=" + str(root / "tmp"),
                    "LANG=C",
                    "LC_ALL=C",
                    "PATH=/usr/bin:/bin",
                ]
            )
        command.extend(
            [
                "/usr/bin/python3",
                "-I",
                "-S",
                "-B",
                str(AUDIT_PATH),
                "sterile-python",
                "--root",
                str(root),
                "--repository",
                str(repository),
                "--",
                "bootstrap-self-test",
            ]
        )
        env = os.environ.copy()
        env.update(extra_env or {})
        return subprocess.run(
            command,
            cwd=str(repository),
            env=env,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=10,
            check=False,
        )

    def test_exact_outer_boundary_scrubs_hostile_parent_and_reports_frozen_flags(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            repository = base / "repository"
            _mkdir(repository)
            marker = base / "marker"
            keylog = base / "tls.keys"
            bash_env = base / "bash-env"
            bash_env.write_text("touch " + str(marker) + "\n", encoding="utf-8")
            hostile = base / "hostile-bin"
            _mkdir(hostile)
            result = self._invoke(
                root,
                repository,
                outer_env_i=True,
                extra_env={
                    "BASH_ENV": str(bash_env),
                    "ENV": str(bash_env),
                    "PATH": str(hostile),
                    "PYTHONHOME": str(base / "python-home"),
                    "PYTHONPATH": str(base / "python-path"),
                    "SSLKEYLOGFILE": str(keylog),
                    "HTTPS_PROXY": "http://127.0.0.1:9",
                },
            )
            self.assertEqual(result.returncode, 0, result.stderr.decode("utf-8", "replace"))
            record = json.loads(result.stdout)
            self.assertEqual(record["schemaVersion"], "qinao.sterile-python.v1")
            self.assertEqual(
                record["flags"],
                {
                    "isolated": 1,
                    "ignoreEnvironment": 1,
                    "noSite": 1,
                    "noUserSite": 1,
                    "dontWriteBytecode": 1,
                },
            )
            self.assertNotIn(str(repository), record["sysPath"])
            self.assertFalse(marker.exists())
            self.assertFalse(keylog.exists())
            self.assertEqual(list(repository.rglob("*.pyc")), [])
            self.assertEqual(list(repository.rglob("__pycache__")), [])

    def test_forbidden_environment_is_rejected_before_target_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            repository = base / "repository"
            _mkdir(repository)
            result = self._invoke(
                root,
                repository,
                outer_env_i=False,
                extra_env={"SSLKEYLOGFILE": str(base / "should-not-exist")},
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn(b"forbidden environment", result.stderr)
            self.assertFalse((base / "should-not-exist").exists())

    def test_local_stdlib_shadow_and_import_artifacts_are_rejected(self):
        for relative in ("json.py", "sitecustomize.py", "x.pth", "x.pyc", "pkg.egg"):
            with self.subTest(relative=relative), tempfile.TemporaryDirectory() as temporary:
                base = Path(temporary)
                root = _new_run_root(base)
                repository = base / "repository"
                _mkdir(repository)
                (repository / relative).write_bytes(b"raise SystemExit(91)\n")
                result = self._invoke(root, repository, outer_env_i=True)
                self.assertEqual(result.returncode, 2)
                self.assertIn(b"undeclared import artifact", result.stderr)

    def test_only_closed_target_modes_are_accepted(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            repository = base / "repository"
            _mkdir(repository)
            with self.assertRaisesRegex(module.AuditError, "closed target"):
                module.validate_sterile_target(["-c", "print(1)"], profile="bootstrap")
            with self.assertRaisesRegex(module.AuditError, "closed target"):
                module.validate_sterile_target(["-"] , profile="bootstrap")

    def test_runtime_projection_closes_interpreter_stdlib_openssl_and_ca(self):
        projection = module.sterile_runtime_projection()
        self.assertEqual(projection["executable"], "/usr/bin/python3")
        self.assertRegex(projection["interpreterSha256"], r"\A[0-9a-f]{64}\Z")
        self.assertRegex(projection["stdlibDigest"], r"\A[0-9a-f]{64}\Z")
        self.assertRegex(projection["opensslDigest"], r"\A[0-9a-f]{64}\Z")
        self.assertRegex(projection["defaultCADigest"], r"\A[0-9a-f]{64}\Z")


class LedgerTests(_ModuleRequired):
    """Breaks caught: a run record is mutable, ambiguous, or silently reused."""

    def test_identity_and_initial_chain_are_canonical_create_once_and_mode_closed(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            identity = module.init_run_state(
                root,
                _identity_fields(base),
                bootstrap_imports=[],
            )
            self.assertRegex(identity["runId"], r"\A[0-9a-f]{32}\Z")
            self.assertEqual(_mode(root / "ledger"), 0o700)
            self.assertEqual(_mode(root / "ledger" / "identity.json"), 0o600)
            self.assertEqual(_mode(root / "ledger" / "lock"), 0o600)
            recovered = module.recover_run_state(root)
            self.assertEqual(recovered["classification"], "complete")
            self.assertEqual(recovered["nextSequence"], 2)
            with self.assertRaisesRegex(module.AuditError, "identity mismatch"):
                changed = dict(_identity_fields(base), C="e" * 40)
                module.init_run_state(root, changed, bootstrap_imports=[])

    def test_records_form_contiguous_self_digest_chain_and_tamper_is_indeterminate(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            module.init_run_state(root, _identity_fields(base), bootstrap_imports=[])
            start = module.frontier_start(
                root,
                frontier_kind="task",
                input_digest="1" * 64,
                declared_paths=["scripts/a.py"],
                expected_tests=["test_red"],
            )
            module.frontier_complete(
                root,
                start["frontierId"],
                input_digest="1" * 64,
                declared_paths=["scripts/a.py"],
                outcome="completed",
            )
            recovered = module.recover_run_state(root)
            self.assertEqual([row["sequence"] for row in recovered["records"]], [1, 2, 3])
            self.assertEqual(recovered["openFrontiers"], [])
            record = root / "ledger" / "records" / "0000000000000002.json"
            original = record.read_bytes()
            record.write_bytes(original.replace(b"task", b"tusk", 1))
            before = sorted(str(path) for path in root.rglob("*"))
            recovered = module.recover_run_state(root)
            after = sorted(str(path) for path in root.rglob("*"))
            self.assertEqual(recovered["classification"], "indeterminate")
            self.assertEqual(before, after)

    def test_peer_frontier_rule_and_exact_completion_binding(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            module.init_run_state(root, _identity_fields(base), bootstrap_imports=[])
            first = module.frontier_start(
                root,
                frontier_kind="task",
                input_digest="2" * 64,
                declared_paths=["scripts/a.py"],
                expected_tests=["red-a"],
            )
            with self.assertRaisesRegex(module.AuditError, "open peer"):
                module.frontier_start(
                    root,
                    frontier_kind="task",
                    input_digest="3" * 64,
                    declared_paths=["scripts/b.py"],
                    expected_tests=["red-b"],
                )
            with self.assertRaisesRegex(module.AuditError, "declared path"):
                module.frontier_complete(
                    root,
                    first["frontierId"],
                    input_digest="2" * 64,
                    declared_paths=["scripts/wrong.py"],
                    outcome="completed",
                )

    def test_resource_child_is_single_bound_and_blocks_parent_completion(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            module.init_run_state(root, _identity_fields(base), bootstrap_imports=[])
            parent = module.frontier_start(
                root,
                frontier_kind="task",
                input_digest="4" * 64,
                declared_paths=["scripts/a.py"],
                expected_tests=["red"],
                allowed_child_kinds=["cargo-archive-census"],
            )
            resource = module.allocate_resource(root, "crate-cache")
            child = module.frontier_start(
                root,
                frontier_kind="local-resource",
                input_digest="5" * 64,
                declared_paths=[],
                expected_tests=[],
                parent_frontier=parent["frontierId"],
                component_kind="cargo-archive-census",
                resource_id=resource["resourceId"],
                operation_class="read-only-no-remote-write",
            )
            with self.assertRaisesRegex(module.AuditError, "child is open"):
                module.frontier_complete(
                    root,
                    parent["frontierId"],
                    input_digest="4" * 64,
                    declared_paths=["scripts/a.py"],
                    outcome="completed",
                )
            with self.assertRaisesRegex(module.AuditError, "one child"):
                module.frontier_start(
                    root,
                    frontier_kind="local-resource",
                    input_digest="6" * 64,
                    declared_paths=[],
                    expected_tests=[],
                    parent_frontier=parent["frontierId"],
                    component_kind="cargo-archive-census",
                    resource_id=resource["resourceId"],
                    operation_class="read-only-no-remote-write",
                )
            snapshot = module.snapshot_resource(root, resource["resourceId"], child["frontierId"])
            module.frontier_complete(
                root,
                child["frontierId"],
                input_digest="5" * 64,
                declared_paths=[],
                outcome="tainted-preserved",
                resource_snapshot_digest=snapshot["snapshotDigest"],
            )

    def test_capture_allocation_is_never_reused_and_seal_is_exact_whitelist(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            module.init_run_state(root, _identity_fields(base), bootstrap_imports=[])
            capture = module.allocate_capture(root, "unit")
            capture_path = Path(capture["absolutePath"])
            (capture_path / "payload.bin").write_bytes(b"alpha\x00beta")
            os.chmod(capture_path / "payload.bin", 0o600)
            with self.assertRaisesRegex(module.AuditError, "whitelist"):
                module.seal_capture(root, capture["captureId"], [])
            sealed = module.seal_capture(root, capture["captureId"], ["payload.bin"])
            self.assertRegex(sealed["sealDigest"], r"\A[0-9a-f]{64}\Z")
            self.assertEqual(_mode(capture_path / "manifest.json"), 0o600)
            with self.assertRaisesRegex(module.AuditError, "already sealed"):
                module.seal_capture(root, capture["captureId"], ["payload.bin"])
            second = module.allocate_capture(root, "unit")
            self.assertNotEqual(capture["captureId"], second["captureId"])
            self.assertNotEqual(capture["absolutePath"], second["absolutePath"])

    def test_capture_seal_rejects_symlink_special_and_hard_link(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            module.init_run_state(root, _identity_fields(base), bootstrap_imports=[])
            capture = module.allocate_capture(root, "unit")
            capture_path = Path(capture["absolutePath"])
            target = capture_path / "target"
            target.write_bytes(b"x")
            os.link(target, capture_path / "hard")
            with self.assertRaisesRegex(module.AuditError, "hard link"):
                module.seal_capture(root, capture["captureId"], ["target", "hard"])
            target.unlink()
            (capture_path / "hard").unlink()
            os.symlink("missing", capture_path / "link")
            with self.assertRaisesRegex(module.AuditError, "ordinary"):
                module.seal_capture(root, capture["captureId"], ["link"])

    def test_resource_snapshot_is_nul_safe_and_detects_concurrent_or_unsafe_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            module.init_run_state(root, _identity_fields(base), bootstrap_imports=[])
            task = module.frontier_start(
                root,
                frontier_kind="task",
                input_digest="7" * 64,
                declared_paths=[],
                expected_tests=[],
                allowed_child_kinds=["cargo-archive-census"],
            )
            resource = module.allocate_resource(root, "cache")
            child = module.frontier_start(
                root,
                frontier_kind="local-resource",
                input_digest="8" * 64,
                declared_paths=[],
                expected_tests=[],
                parent_frontier=task["frontierId"],
                component_kind="cargo-archive-census",
                resource_id=resource["resourceId"],
                operation_class="read-only-no-remote-write",
            )
            resource_path = Path(resource["absolutePath"])
            # A newline/control byte exercises the NUL-safe identity path on
            # every supported test filesystem.  The managed macOS sandbox
            # rejects non-UTF-8 pathname creation before APFS sees it.
            raw_name = "bad_\nname"
            (resource_path / raw_name).write_bytes(b"payload")
            snapshot = module.snapshot_resource(root, resource["resourceId"], child["frontierId"])
            decoded = [base64.b64decode(row["pathB64"]) for row in snapshot["entries"]]
            self.assertIn(os.fsencode(raw_name), decoded)
            os.symlink("missing", resource_path / "unsafe")
            with self.assertRaisesRegex(module.AuditError, "symlink"):
                module.snapshot_resource(root, resource["resourceId"], child["frontierId"])

    def test_short_writes_are_completed_and_fsync_failure_is_not_reported_complete(self):
        sink = io.BytesIO()

        def short_write(_fd, payload):
            take = min(2, len(payload))
            sink.write(bytes(payload[:take]))
            return take

        with mock.patch.object(module.os, "write", side_effect=short_write):
            module._write_all(123, b"abcdef")
        self.assertEqual(sink.getvalue(), b"abcdef")
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "record"
            with mock.patch.object(module.os, "fsync", side_effect=OSError("fsync failed")):
                with self.assertRaisesRegex(OSError, "fsync failed"):
                    module.write_canonical_exclusive(path, {"kind": "test"})

    def test_exact_erratum_probes_are_non_evidentiary_and_fourth_or_drift_blocks(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            for name in EXACT_PROBES:
                _write_exact_probe(root / "bootstrap", name)
            observed = module.validate_controller_erratum_probes(root / "bootstrap")
            self.assertEqual([row["name"] for row in observed], list(EXACT_PROBES))
            self.assertTrue(all(row["classification"] == "forensic-controller-erratum" for row in observed))
            self.assertTrue(all(row["evidentiary"] is False for row in observed))
            _write_exact_probe(root / "bootstrap", "probe.fourth")
            with self.assertRaisesRegex(module.AuditError, "fourth|unknown probe"):
                module.validate_controller_erratum_probes(root / "bootstrap")
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            for name in EXACT_PROBES:
                _write_exact_probe(root / "bootstrap", name)
            (root / "bootstrap" / EXACT_PROBES[0] / "objects" / "drift").write_bytes(b"x")
            with self.assertRaisesRegex(module.AuditError, "probe shape"):
                module.validate_controller_erratum_probes(root / "bootstrap")

    def test_n34_empty_primary_is_phase_aware_digest_bound_and_partials_are_preserved(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            bootstrap = root / "bootstrap"
            for name in EXACT_PROBES:
                _write_exact_probe(bootstrap, name)
            for name in ("tree-prediction.GIzGps", "tree-prediction.tRMizn", "tree-prediction.oizOwr"):
                generation = bootstrap / name
                _mkdir(generation)
                _mkdir(generation / "objects")
            _write_n34_generation(bootstrap)
            rows = module.classify_tree_prediction_generations(
                bootstrap,
                expected_tree=EXPECTED_TREE,
                expected_c="c" * 40,
                erratum_digest=ERRATUM_DIGEST,
            )
            by_name = {row["name"]: row for row in rows}
            self.assertEqual(by_name["tree-prediction.N34crC"]["classification"], "forensic-complete-alternate-reuse")
            for name in ("tree-prediction.GIzGps", "tree-prediction.tRMizn", "tree-prediction.oizOwr"):
                self.assertEqual(by_name[name]["classification"], "forensic-partial")
                self.assertTrue((bootstrap / name).is_dir())
            proof = bootstrap / "tree-prediction.N34crC" / "alternate-reuse-proof.tsv"
            proof.write_bytes(proof.read_bytes().replace(ERRATUM_DIGEST.encode(), b"0" * 64))
            with self.assertRaisesRegex(module.AuditError, "erratum digest"):
                module.classify_tree_prediction_generations(
                    bootstrap,
                    expected_tree=EXPECTED_TREE,
                    expected_c="c" * 40,
                    erratum_digest=ERRATUM_DIGEST,
                )

    def test_empty_primary_is_rejected_outside_the_sole_post_c_generation(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            generation = root / "bootstrap" / "tree-prediction.not-N34"
            _mkdir(generation)
            _mkdir(generation / "objects")
            (generation / "result.tsv").write_text(
                "predicted_tree=" + EXPECTED_TREE + "\n",
                encoding="ascii",
            )
            with self.assertRaisesRegex(module.AuditError, "empty primary"):
                module.classify_tree_prediction_generations(
                    root / "bootstrap",
                    expected_tree=EXPECTED_TREE,
                    expected_c="c" * 40,
                    erratum_digest=ERRATUM_DIGEST,
                )

    def test_bootstrap_inventory_imports_every_generation_without_promoting_partials(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            bootstrap = root / "bootstrap"
            for name in EXACT_PROBES:
                _write_exact_probe(bootstrap, name)
            partial = bootstrap / "tree-prediction.partial"
            _mkdir(partial)
            _mkdir(partial / "objects")
            _write_n34_generation(bootstrap)

            incomplete = bootstrap / "capture.task2.partial"
            _mkdir(incomplete)
            (incomplete / "fact.bin").write_bytes(b"immutable partial")
            failed = bootstrap / "capture.task3.failed"
            _mkdir(failed)
            (failed / "failure.json").write_bytes(b"{}\n")
            (failed / "terminal.failed").write_bytes(b"failed\n")
            scanner = bootstrap / "capture.task3.scanner"
            _mkdir(scanner)
            scan_record = module._self_digest_record(
                {
                    "schemaVersion": "qinao.secret-scan-worktree.v1",
                    "ruleSetVersion": module.RULE_SET_VERSION,
                    "ruleSetDigest": module.RULE_SET_DIGEST,
                    "ruleCount": len(module.SECRET_RULES),
                    "scannedFileCount": 2,
                    "scannedByteCount": 17,
                    "findingCount": 0,
                    "entries": [],
                    "findings": [],
                }
            )
            module.write_canonical_exclusive(scanner / "secret-scan.json", scan_record)
            (scanner / "terminal.complete").write_bytes(b"complete\n")
            for path in bootstrap.rglob("*"):
                if path.is_file():
                    os.chmod(path, 0o600)

            rows = module.collect_bootstrap_imports(
                root,
                scanner_record=scanner / "secret-scan.json",
                expected_tree=EXPECTED_TREE,
                expected_c="c" * 40,
                erratum_digest=ERRATUM_DIGEST,
            )
            by_name = {row["name"]: row for row in rows}
            expected_names = set(EXACT_PROBES) | {
                "tree-prediction.partial",
                "tree-prediction.N34crC",
                "capture.task2.partial",
                "capture.task3.failed",
                "capture.task3.scanner",
            }
            self.assertEqual(set(by_name), expected_names)
            self.assertEqual(
                by_name["capture.task2.partial"]["classification"],
                "forensic-partial",
            )
            self.assertEqual(
                by_name["capture.task3.failed"]["classification"],
                "forensic-complete-failed",
            )
            self.assertEqual(
                by_name["capture.task3.scanner"]["classification"],
                "bootstrap-secret-scan-complete",
            )
            self.assertEqual(
                by_name["tree-prediction.N34crC"]["erratumDigest"],
                ERRATUM_DIGEST,
            )
            self.assertTrue(
                all(row["bootstrapImportDigest"] == module._sha256(
                    module.canonical_json_bytes(
                        {key: value for key, value in row.items() if key != "bootstrapImportDigest"}
                    )
                ) for row in rows)
            )

    def test_init_transition_manifest_is_terminal_before_dispatch_and_never_finished(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            invocation = module._self_digest_record(
                {
                    "schemaVersion": "qinao.sterile-invocation.v1",
                    "profile": "bootstrap",
                    "argv": ["init-run-state"],
                }
            )
            diagnostic = module._bootstrap_init_transition(root, invocation)
            self.assertEqual(
                sorted(path.name for path in diagnostic.iterdir()),
                ["invocation.json", "terminal.transition"],
            )
            before = {
                path.name: path.read_bytes()
                for path in diagnostic.iterdir()
            }
            module._bootstrap_invocation_finish_if_needed(
                diagnostic,
                exit_code=0,
                is_init_transition=True,
            )
            after = {
                path.name: path.read_bytes()
                for path in diagnostic.iterdir()
            }
            self.assertEqual(before, after)

    def test_init_and_frontier_cli_round_trip_use_only_committed_primitives(self):
        class BinaryStdout:
            def __init__(self):
                self.buffer = io.BytesIO()

            def write(self, value):
                return len(value)

            def flush(self):
                return None

        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = _new_run_root(base)
            repository = base / "repository"
            _mkdir(repository)
            scanner = root / "bootstrap" / "capture.scanner"
            _mkdir(scanner)
            scan_file = scanner / "secret-scan.json"
            scan_file.write_bytes(b"{}\n")
            os.chmod(scan_file, 0o600)
            facts = module._self_digest_record(
                {
                    "schemaVersion": "qinao.bootstrap-facts.v1",
                    "bootstrapCommit": "a" * 40,
                },
                field="bootstrapImportDigest",
            )
            stream = BinaryStdout()
            with mock.patch.object(
                module,
                "_build_convergence_bootstrap_context",
                return_value=(_identity_fields(repository), facts),
            ), mock.patch.object(
                module,
                "collect_bootstrap_imports",
                return_value=[],
            ), mock.patch.object(module.sys, "stdout", stream):
                self.assertEqual(
                    module._dispatch_command(
                        [
                            "init-run-state",
                            "--root",
                            str(root),
                            "--repository",
                            str(repository),
                            "--profile",
                            "convergence",
                            "--bootstrap-import",
                            str(scan_file),
                        ]
                    ),
                    0,
                )
            self.assertEqual(module.recover_run_state(root)["classification"], "complete")

            stream = BinaryStdout()
            with mock.patch.object(module.sys, "stdout", stream):
                self.assertEqual(
                    module._dispatch_command(
                        [
                            "frontier-start",
                            "--root",
                            str(root),
                            "--frontier-kind",
                            "task",
                            "--input-digest",
                            "7" * 64,
                            "--declared-path",
                            "scripts/qinao_convergence_audit.py",
                            "--expected-test",
                            "RawDiffTests",
                        ]
                    ),
                    0,
                )
            started = module.parse_canonical_json(stream.buffer.getvalue())
            self.assertEqual(
                module.recover_run_state(root)["openFrontiers"][0]["frontierId"],
                started["frontierId"],
            )

            stream = BinaryStdout()
            with mock.patch.object(module.sys, "stdout", stream):
                self.assertEqual(
                    module._dispatch_command(
                        [
                            "frontier-complete",
                            "--root",
                            str(root),
                            "--frontier-id",
                            started["frontierId"],
                            "--input-digest",
                            "7" * 64,
                            "--declared-path",
                            "scripts/qinao_convergence_audit.py",
                            "--outcome",
                            "completed",
                        ]
                    ),
                    0,
                )
            self.assertEqual(module.recover_run_state(root)["openFrontiers"], [])

    def test_bootstrap_commit_metadata_rejects_optional_headers_and_identity_drift(self):
        raw = (
            b"tree " + (b"1" * 40) + b"\n"
            b"parent " + (b"2" * 40) + b"\n"
            b"author Qinao development <qinao-development@invalid.local> 1788000000 +1000\n"
            b"committer Qinao development <qinao-development@invalid.local> 1788000001 +1000\n"
            b"\n"
            b"feat: add durable Qinao run ledger\n"
        )
        parsed = module.parse_bootstrap_commit_metadata(
            raw,
            expected_tree="1" * 40,
            expected_parent="2" * 40,
        )
        self.assertEqual(parsed["message"], "feat: add durable Qinao run ledger\n")
        self.assertRegex(parsed["rawCommitSha256"], r"\A[0-9a-f]{64}\Z")
        with self.assertRaisesRegex(module.AuditError, "header"):
            module.parse_bootstrap_commit_metadata(
                raw.replace(b"\n\n", b"\nencoding UTF-8\n\n", 1),
                expected_tree="1" * 40,
                expected_parent="2" * 40,
            )
        with self.assertRaisesRegex(module.AuditError, "identity"):
            module.parse_bootstrap_commit_metadata(
                raw.replace(b"Qinao development", b"Other identity", 1),
                expected_tree="1" * 40,
                expected_parent="2" * 40,
            )


class SecretScanWorktreeTests(_ModuleRequired):
    """Breaks caught: unselected bytes or matched secret bytes reach a commit."""

    def test_scans_index_and_declared_dirty_bytes_with_positive_counts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            dirty = root / "scripts" / "dirty.py"
            dirty.parent.mkdir()
            dirty.write_bytes(b"print('safe')\n")
            result = module.secret_scan_worktree_selection(
                index_entries={b"scripts/indexed.py": b"x = 1\n"},
                repository=root,
                declared_paths=[b"scripts/dirty.py"],
                actual_dirty_paths=[b"scripts/dirty.py"],
            )
            self.assertEqual(result["findingCount"], 0)
            self.assertEqual(result["scannedFileCount"], 2)
            self.assertGreater(result["scannedByteCount"], 0)
            self.assertGreater(result["ruleCount"], 0)
            self.assertRegex(result["ruleSetDigest"], r"\A[0-9a-f]{64}\Z")

    def test_local_git_adapter_never_supplies_input_and_stdin_together(self):
        def strict_run(*args, **kwargs):
            if "input" in kwargs and kwargs.get("stdin") is not None:
                raise ValueError("stdin and input arguments may not both be used")
            return subprocess.CompletedProcess(args[0], 0, stdout=b"safe", stderr=b"")

        with tempfile.TemporaryDirectory() as temporary:
            with mock.patch.object(module.subprocess, "run", side_effect=strict_run):
                self.assertEqual(module._run_git(Path(temporary), ["version"]), b"safe")

    def test_secret_hit_is_redacted_and_blocks(self):
        secret = ("gh" + "p_" + "A" * 40).encode("ascii")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaises(module.SecretScanError) as raised:
                module.secret_scan_worktree_selection(
                    index_entries={b"scripts/a.py": b"value = b'" + secret + b"'\n"},
                    repository=root,
                    declared_paths=[],
                    actual_dirty_paths=[],
                )
            message = str(raised.exception)
            self.assertIn("secret scan hit", message)
            self.assertNotIn(secret.decode("ascii"), message)
            self.assertEqual(raised.exception.record["findingCount"], 1)
            self.assertEqual(
                raised.exception.record["findings"][0]["ruleId"],
                "github-classic-token",
            )
            self.assertNotIn(secret.decode("ascii"), json.dumps(raised.exception.record))

    def test_symbolic_credential_assignment_is_not_a_secret(self):
        payload = b"access" + b"Token = response.access_token\n"
        self.assertEqual(module._scan_payload(b"source.swift", payload), [])

    def test_quoted_credential_assignment_is_still_a_secret(self):
        payload = b"access" + b"Token = '" + (b"Z" * 24) + b"'\n"
        findings = module._scan_payload(b"source.swift", payload)
        self.assertEqual([item["ruleId"] for item in findings], ["credential-assignment"])

    def test_secret_scan_failure_persists_only_redacted_bootstrap_diagnostic(self):
        secret = ("gh" + "p_" + "B" * 40).encode("ascii")
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            repository = base / "repository"
            bootstrap = base / "bootstrap"
            _mkdir(repository)
            _mkdir(bootstrap)
            with mock.patch.object(
                module,
                "_git_index_entries",
                return_value={b"scripts/a.py": b"value = b'" + secret + b"'\n"},
            ), mock.patch.object(module, "_git_dirty_paths", return_value=[]):
                with self.assertRaises(module.SecretScanError):
                    module._command_secret_scan_worktree(
                        [
                            "--repository",
                            str(repository),
                            "--bootstrap-diagnostic-root",
                            str(bootstrap),
                        ]
                    )
            diagnostics = list(bootstrap.glob("capture.task3-secret.*"))
            self.assertEqual(len(diagnostics), 1)
            record = module.parse_canonical_json(
                (diagnostics[0] / "secret-scan.json").read_bytes()
            )
            self.assertEqual(record["findingCount"], 1)
            self.assertEqual((diagnostics[0] / "terminal.failed").read_bytes(), b"failed\n")
            persisted = (diagnostics[0] / "secret-scan.json").read_text("utf-8")
            self.assertNotIn(secret.decode("ascii"), persisted)

    def test_zero_selection_undeclared_dirty_symlink_and_output_collision_block(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(module.AuditError, "zero selection"):
                module.secret_scan_worktree_selection({}, root, [], [])
            path = root / "x.py"
            path.write_bytes(b"safe\n")
            with self.assertRaisesRegex(module.AuditError, "undeclared dirty"):
                module.secret_scan_worktree_selection({}, root, [], [b"x.py"])
            path.unlink()
            os.symlink("missing", path)
            with self.assertRaisesRegex(module.AuditError, "ordinary"):
                module.secret_scan_worktree_selection({}, root, [b"x.py"], [b"x.py"])
            output = root / "result.json"
            output.write_bytes(b"existing")
            with self.assertRaises(FileExistsError):
                module.write_canonical_exclusive(output, {"kind": "scan"})

    def test_python_entrypoint_scanner_accepts_only_three_exact_shapes_and_quarantines_debt(self):
        exact = {
            b"local.sh": module.LOCAL_PYTHON_LAUNCHER,
            b"ci.yml": module.CI_PYTHON_PREFIX,
            b"bootstrap.txt": module.BOOTSTRAP_TEST_COMMAND,
        }
        result = module.validate_python_entrypoint_stream(exact, mode="at-C")
        self.assertEqual(result["executableEntrypointCount"], 3)
        debt_payload = (AUDIT_PATH.parents[1] / module.HISTORICAL_DEBT_PATH.decode()).read_bytes()
        self.assertEqual(hashlib.sha256(debt_payload).hexdigest(), module.HISTORICAL_DEBT_SHA256)
        debt = {
            module.HISTORICAL_DEBT_PATH: debt_payload,
        }
        result = module.validate_python_entrypoint_stream(
            debt,
            mode="at-C",
            debt_callers=module.HISTORICAL_DEBT_CALLERS,
        )
        self.assertEqual(result["migrationDebtCount"], 1)
        self.assertEqual(
            result["migrationDebtCallerDigest"],
            hashlib.sha256(b"\x00".join(module.HISTORICAL_DEBT_CALLERS) + b"\x00").hexdigest(),
        )
        with self.assertRaisesRegex(module.AuditError, "caller"):
            module.validate_python_entrypoint_stream(
                debt,
                mode="at-C",
                debt_callers=module.HISTORICAL_DEBT_CALLERS + (b"unexpected.sh",),
            )
        with self.assertRaisesRegex(module.AuditError, "migration debt"):
            module.validate_python_entrypoint_stream(
                debt,
                mode="final-H",
                debt_callers=module.HISTORICAL_DEBT_CALLERS,
            )

    def test_python_entrypoint_scanner_rejects_raw_drift_and_unrooted_fence(self):
        drift = module.BOOTSTRAP_TEST_COMMAND.replace(b" -B ", b" ", 1)
        with self.assertRaisesRegex(module.AuditError, "raw Python"):
            module.validate_python_entrypoint_stream({b"bad.sh": drift}, mode="at-C")
        fence = b"```bash\npython3 -m unittest\n```\n"
        with self.assertRaisesRegex(module.AuditError, "sterile outer shell"):
            module.validate_plan_fence_stream({b"plan.md": fence})

    def test_canonical_json_rejects_duplicate_float_unsafe_integer_and_bad_unicode(self):
        bad_payloads = (
            b'{"a":1,"a":2}\n',
            b'{"a":1.25}\n',
            b'{"a":9007199254740992}\n',
            b'{"a":"\\ud800"}\n',
        )
        for payload in bad_payloads:
            with self.subTest(payload=payload):
                with self.assertRaises(module.AuditError):
                    module.parse_canonical_json(payload)


if __name__ == "__main__":
    unittest.main()
