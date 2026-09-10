from __future__ import annotations

import copy
import fcntl
import hashlib
import io
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from typing import Optional
from unittest import mock

from scripts import check_artifact_mesh_device_recovery as checker
from scripts import run_artifact_mesh_device_recovery as runner


SCRIPT_DIRECTORY = Path(__file__).resolve().parent
CHECKER_SCRIPT = SCRIPT_DIRECTORY / "check_artifact_mesh_device_recovery.py"
RUNNER_SCRIPT = SCRIPT_DIRECTORY / "run_artifact_mesh_device_recovery.py"


def canonical_protocol_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def protocol_digest(domain: str, value: object) -> str:
    return hashlib.sha256(
        domain.encode("ascii") + b"\0" + canonical_protocol_bytes(value)
    ).hexdigest()


def send_protocol_frame(capability: socket.socket, value: object) -> None:
    raw = canonical_protocol_bytes(value)
    capability.sendall(len(raw).to_bytes(8, "big") + raw)


def receive_protocol_frame(capability: socket.socket) -> object:
    header = capability.recv(8, socket.MSG_WAITALL)
    if len(header) != 8:
        raise AssertionError("missing protocol header")
    length = int.from_bytes(header, "big")
    raw = capability.recv(length, socket.MSG_WAITALL)
    if len(raw) != length:
        raise AssertionError("missing protocol payload")
    return json.loads(raw.decode("utf-8"))


def protocol_fixture(
    candidate_commit: str = "a" * 40,
    candidate_tree: str = "b" * 40,
    matrix_digest: str = "f" * 64,
) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    common = {
        "operationID": "w1.artifact-mesh-contract-freeze",
        "commandID": "w1.artifact-mesh.device-recovery",
        "candidateCommitOID": candidate_commit,
        "candidateTreeOID": candidate_tree,
        "policyRoot": "c" * 64,
        "challengeDigest": "d" * 64,
        "deviceProfileDigest": "e" * 64,
        "matrixDigest": matrix_digest,
        "custodyManifestDigest": "1" * 64,
    }
    lease: dict[str, object] = {
        "schema": "QinaoArtifactMeshDeviceRecoveryLeaseV1",
        "schemaVersion": 1,
        "authority": "runnerAuthenticated",
        **common,
    }
    lease_digest = protocol_digest(
        "qinao.artifact-mesh.device-recovery.lease.v1",
        lease,
    )
    broker_request = {
        "schema": "QinaoArtifactMeshPhysicalBrokerRequestV1",
        "schemaVersion": 1,
        **common,
        "leaseDigest": lease_digest,
    }
    request_digest = protocol_digest(
        "qinao.artifact-mesh.physical-broker.request.v1",
        broker_request,
    )
    store_identity = "11111111-2222-3333-4444-555555555555"
    previous = "0" * 64
    events: list[dict[str, object]] = []
    for index, expected in enumerate(checker.expected_matrix()["rows"]):
        event: dict[str, object] = {
            "index": index,
            "scenarioID": expected["scenarioID"],
            "initialState": expected["initialState"],
            "cut": expected["cut"],
            "mandatoryFaultAction": expected["mandatoryFaultAction"],
            "faultTiming": expected["faultTiming"],
            "observedReopenDisposition": expected["expectedReopenDisposition"],
            "observedStoreIdentity": store_identity,
            "observedGeneration": expected["expectedGeneration"],
            "observedRecordRoot": "2" * 64,
            "observedCASHead": "3" * 64,
            "observedOrdinaryPutFloor": expected["expectedOrdinaryPutFloor"],
            "observedRecoveryFloor": expected["expectedRecoveryFloor"],
            "previousEventDigest": previous,
        }
        event["eventDigest"] = protocol_digest(
            "qinao.artifact-mesh.device-event.v1",
            event,
        )
        previous = str(event["eventDigest"])
        events.append(event)
    assertion_counts = (
        ("w1.assert.device-physical-40-of-40", 40),
        ("w1.assert.two-process-cas", 2),
        ("w1.assert.persist-wal-full", 3),
        ("w1.assert.sidecars-protected", 3),
        ("w1.assert.atomic-quarantine", 1),
        ("w1.assert.preunlock-zero-mutation", 1),
        ("w1.assert.factory-external-reopen", 1),
        ("w1.assert.release-exclusion", 1),
        ("w1.assert.custody-cleanup", 1),
    )
    assertions = [
        {
            "assertionID": assertion_id,
            "evidenceDigest": format(index + 4, "064x"),
            "expectedObservationCount": count,
            "observedObservationCount": count,
            "violationCount": 0,
        }
        for index, (assertion_id, count) in enumerate(assertion_counts)
    ]
    archive = {
        "schema": "QinaoArtifactMeshShippingArchiveFactsV1",
        "archiveDigest": "a" * 64,
        "codeIdentityRoot": "b" * 64,
        "productManifestRoot": "c" * 64,
        "scanManifestDigest": "d" * 64,
        "shippingProductCount": 1,
        "linkMapCount": 1,
        "moduleInterfaceCount": 1,
        "labProductCount": 0,
        "forbiddenConditionCount": 0,
        "forbiddenSymbolCount": 0,
    }
    external_reopen = {
        "schema": "QinaoArtifactMeshExternalReopenFactsV1",
        "factorySymbol": "QinaoDefaults.makeArtifactMeshStore(configuration:)",
        "storeIdentity": store_identity,
        "storeLineageDigest": "4" * 64,
        "generation": 2,
        "recordRoot": "2" * 64,
        "casHead": "3" * 64,
        "ordinaryPutFloor": 1,
        "recoveryFloor": 1,
        "putRecordDigest": "5" * 64,
        "reopenedRecordDigest": "5" * 64,
        "openProcessID": 101,
        "reopenProcessID": 202,
        "reopenDisposition": "resume",
    }
    broker_response: dict[str, object] = {
        "schema": "QinaoArtifactMeshPhysicalBrokerEvidenceV1",
        "schemaVersion": 1,
        "producer": "protectedPhysicalBroker",
        **common,
        "leaseDigest": lease_digest,
        "requestDigest": request_digest,
        "events": events,
        "eventChainRoot": previous,
        "physicalAssertions": assertions,
        "archiveAttestation": archive,
        "externalReopenFacts": external_reopen,
        "terminal": "physicalEvidenceComplete",
    }
    broker_response_digest = protocol_digest(
        "qinao.artifact-mesh.physical-broker.evidence.v1",
        broker_response,
    )
    custody_request = {
        "schema": "QinaoArtifactMeshCustodyCleanupRequestV1",
        "schemaVersion": 1,
        **common,
        "leaseDigest": lease_digest,
        "brokerResponseDigest": broker_response_digest,
        "eventChainRoot": previous,
    }
    custody_request_digest = protocol_digest(
        "qinao.artifact-mesh.custody.request.v1",
        custody_request,
    )
    custody_proof: dict[str, object] = {
        "schema": "QinaoArtifactMeshCustodyProofV1",
        "schemaVersion": 1,
        "producer": "encryptedCustodyBroker",
        **common,
        "leaseDigest": lease_digest,
        "brokerResponseDigest": broker_response_digest,
        "requestDigest": custody_request_digest,
        "overwriteReceiptDigest": "6" * 64,
        "cleanupReceiptDigest": "7" * 64,
        "keyDestructionReceiptDigest": "8" * 64,
        "residueScanDigest": "9" * 64,
        "encryptedRootCount": 1,
        "overwrittenRegularFileCount": 1,
        "cleanupDisposition": "removed",
        "keyDisposition": "destroyed",
        "residueFileCount": 0,
        "residueByteCount": 0,
        "terminal": "custodyClosed",
    }
    return lease, broker_response, custody_proof


def evidence_documents(
    candidate_commit: str = "a" * 40,
    candidate_tree: str = "b" * 40,
    matrix_digest: str = "f" * 64,
) -> tuple[dict[str, object], ...]:
    _, trace, custody_proof = protocol_fixture(
        candidate_commit,
        candidate_tree,
        matrix_digest,
    )
    common = {key: trace[key] for key in runner.COMMON_BINDING_KEYS}
    broker_response_digest = protocol_digest(
        "qinao.artifact-mesh.physical-broker.evidence.v1",
        trace,
    )
    archive: dict[str, object] = {
        "schema": "QinaoArtifactMeshArchiveAttestationV1",
        "schemaVersion": 1,
        **common,
        "leaseDigest": trace["leaseDigest"],
        "brokerResponseDigest": broker_response_digest,
        "attestation": trace["archiveAttestation"],
    }
    reopen: dict[str, object] = {
        "schema": "QinaoArtifactMeshExternalReopenReceiptV1",
        "schemaVersion": 1,
        **common,
        "leaseDigest": trace["leaseDigest"],
        "brokerResponseDigest": broker_response_digest,
        "facts": trace["externalReopenFacts"],
    }
    archive_digest = protocol_digest(
        "qinao.artifact-mesh.archive-attestation.v1",
        archive,
    )
    reopen_digest = protocol_digest(
        "qinao.artifact-mesh.external-reopen-receipt.v1",
        reopen,
    )
    custody_proof_digest = protocol_digest(
        "qinao.artifact-mesh.custody.proof.v1",
        custody_proof,
    )
    evidence_root = protocol_digest(
        "qinao.artifact-mesh.device-recovery.terminal.v1",
        {
            "leaseDigest": trace["leaseDigest"],
            "brokerResponseDigest": broker_response_digest,
            "custodyProofDigest": custody_proof_digest,
        },
    )
    reachability: dict[str, object] = {
        "schema": "QinaoArtifactMeshProductionReachabilityV1",
        "schemaVersion": 1,
        "authority": "runnerAuthenticated",
        **common,
        "leaseDigest": trace["leaseDigest"],
        "brokerResponseDigest": broker_response_digest,
        "archiveAttestationDigest": archive_digest,
        "externalReopenReceiptDigest": reopen_digest,
        "custodyProofDigest": custody_proof_digest,
        "evidenceRoot": evidence_root,
        "custodyProof": custody_proof,
        "terminal": "validatedPhysicalRecovery",
    }
    return trace, archive, reopen, reachability


class GitMatrixFixture(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(dir="/private/tmp")
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / "repository"
        self.root.mkdir()
        self._git("init", "-q")
        self._git("config", "user.name", "Artifact Matrix Test")
        self._git("config", "user.email", "artifact-matrix@example.invalid")
        self.matrix_path = self.root / checker.MATRIX_RELATIVE_PATH
        self.matrix_path.parent.mkdir(parents=True)
        self.matrix_document = runner.generator_expected_matrix()
        self._write_matrix(self.matrix_document)
        self._git("add", checker.MATRIX_RELATIVE_PATH.as_posix())
        self._git("commit", "-q", "-m", "matrix fixture")
        self.commit = self._git("rev-parse", "HEAD").stdout.strip()
        self.tree = self._git("rev-parse", "HEAD^{tree}").stdout.strip()
        self.output_directory = self.base / "external-output"
        self.output_directory.mkdir()

    def _git(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/usr/bin/git", "-C", os.fspath(self.root), *arguments],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )

    def _write_matrix(self, document: object) -> None:
        self.matrix_path.write_bytes(checker.canonical_json_bytes(document) + b"\n")

    def replaceable_git(self, name: str) -> tuple[Path, Path]:
        marker = self.base / f"{name}-executed"
        executable = self.base / name
        executable.write_text(
            f"#!/bin/sh\n/usr/bin/touch {os.fspath(marker)}\nexit 89\n",
            encoding="utf-8",
        )
        executable.chmod(0o755)
        return executable, marker

    def checker_arguments(self) -> list[str]:
        return [
            "--git-executable",
            os.path.realpath("/usr/bin/git"),
            "--root",
            os.fspath(self.root),
            "--matrix",
            checker.MATRIX_RELATIVE_PATH.as_posix(),
            "--payload-commit",
            self.commit,
            "--payload-tree",
            self.tree,
        ]

    def candidate_arguments(self) -> list[str]:
        return [
            "--mode",
            "candidate-preflight",
            "--git-executable",
            os.path.realpath("/usr/bin/git"),
            "--root",
            os.fspath(self.root),
            "--matrix",
            checker.MATRIX_RELATIVE_PATH.as_posix(),
            "--payload-commit",
            self.commit,
            "--payload-tree",
            self.tree,
            "--device",
            "00008150-00163C6A3E38401C",
            "--development-team",
            "A1B2C3D4E5",
            "--output-directory",
            os.fspath(self.output_directory),
        ]


class ArtifactMeshDeviceRecoveryCheckerTests(GitMatrixFixture):
    def test_checker_rejects_user_owned_replaceable_git_before_execution(
        self,
    ) -> None:
        executable, marker = self.replaceable_git("checker-replaceable-git")
        arguments = self.checker_arguments()
        arguments[arguments.index("--git-executable") + 1] = os.fspath(executable)
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            result = checker.main(arguments)
        self.assertEqual(result, 1)
        self.assertFalse(marker.exists())
        self.assertIn("root-owned", stderr.getvalue())

    def test_git_executable_is_required_exactly_once_and_is_not_path_selected(
        self,
    ) -> None:
        missing = self.checker_arguments()[2:]
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            self.assertEqual(checker.main(missing), 2)
        self.assertIn("--git-executable", stderr.getvalue())

        duplicate = [
            *self.checker_arguments(),
            "--git-executable",
            os.path.realpath("/usr/bin/git"),
        ]
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            self.assertEqual(checker.main(duplicate), 2)
        self.assertIn("exactly once", stderr.getvalue())

        poison_directory = self.base / "poison"
        poison_directory.mkdir()
        poison_git = poison_directory / "git"
        poison_git.write_text("#!/bin/sh\nexit 91\n", encoding="utf-8")
        poison_git.chmod(0o755)
        with mock.patch.dict(os.environ, {"PATH": os.fspath(poison_directory)}):
            stdout = io.StringIO()
            stderr = io.StringIO()
            with redirect_stdout(stdout), redirect_stderr(stderr):
                result = checker.main(self.checker_arguments())
        self.assertEqual(result, 0, stderr.getvalue())
        self.assertIn("PASS mode=matrix", stdout.getvalue())

    def test_git_executable_rejects_relative_symlink_directory_and_nonexecutable(
        self,
    ) -> None:
        regular = self.base / "regular-git"
        regular.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        symlink = self.base / "git-link"
        symlink.symlink_to(os.path.realpath("/usr/bin/git"))
        directory = self.base / "git-directory"
        directory.mkdir()
        invalid = (
            "git",
            os.fspath(symlink),
            os.fspath(directory),
            os.fspath(regular),
        )
        for value in invalid:
            with self.subTest(value=value):
                arguments = self.checker_arguments()
                arguments[1] = value
                with redirect_stderr(io.StringIO()):
                    self.assertEqual(checker.main(arguments), 1)

    def testExactMatrixFixtureRequiresImplementedChecker(self) -> None:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            result = checker.main(self.checker_arguments())
        self.assertEqual(result, 0, stderr.getvalue())
        self.assertEqual(
            stdout.getvalue(),
            "artifact-mesh-device-recovery: PASS mode=matrix "
            "rows=40 no_fault=26 faults=14\n",
        )
        self.assertEqual(stderr.getvalue(), "")
        self.assertNotIn("mode=device", stdout.getvalue())

    def test_closed_corpus_has_exact_operations_rows_keys_and_references(self) -> None:
        document = checker.expected_matrix()
        self.assertEqual(len(document["operations"]), 13)
        self.assertEqual(tuple(document["operations"]), checker.OPERATIONS)
        self.assertEqual(len(document["rows"]), 40)
        self.assertEqual(
            [row["scenarioID"] for row in document["rows"][:4]],
            [
                "nofault.genesisReserve.before",
                "nofault.genesisReserve.after",
                "nofault.genesisSQLiteCommit.before",
                "nofault.genesisSQLiteCommit.after",
            ],
        )
        self.assertEqual(
            [row["scenarioID"] for row in document["rows"][26:]],
            [f"fault.{case[0]}" for case in checker.FAULT_CASES],
        )
        for row in document["rows"]:
            self.assertEqual(set(row), checker.ROW_KEYS)
            self.assertEqual(set(row["cut"]), checker.CUT_KEYS)
            for key, value in checker.SYMBOLIC_REFERENCES.items():
                self.assertEqual(row[key], value)

    def test_each_of_40_row_mutations_is_rejected(self) -> None:
        baseline = checker.expected_matrix()
        for index in range(40):
            with self.subTest(index=index):
                mutated = copy.deepcopy(baseline)
                mutated["rows"][index]["expectedGeneration"] += 1
                with self.assertRaisesRegex(
                    checker.MatrixValidationError,
                    rf"rows\[{index}\]",
                ):
                    checker.validate_matrix_document(mutated)

    def test_shape_order_duplicate_id_boolean_and_future_schema_mutations_fail(
        self,
    ) -> None:
        mutations: list[object] = []
        unknown_outer = copy.deepcopy(checker.expected_matrix())
        unknown_outer["status"] = "passed"
        mutations.append(unknown_outer)
        unknown_row = copy.deepcopy(checker.expected_matrix())
        unknown_row["rows"][0]["result"] = True
        mutations.append(unknown_row)
        bad_cut = copy.deepcopy(checker.expected_matrix())
        bad_cut["rows"][0]["cut"]["phase"] = "before"
        mutations.append(bad_cut)
        duplicate = copy.deepcopy(checker.expected_matrix())
        duplicate["rows"][1]["scenarioID"] = duplicate["rows"][0]["scenarioID"]
        mutations.append(duplicate)
        reordered = copy.deepcopy(checker.expected_matrix())
        reordered["rows"][0], reordered["rows"][1] = (
            reordered["rows"][1],
            reordered["rows"][0],
        )
        mutations.append(reordered)
        boolean = copy.deepcopy(checker.expected_matrix())
        boolean["rows"][0]["expectedGeneration"] = False
        mutations.append(boolean)
        future = copy.deepcopy(checker.expected_matrix())
        future["schema_version"] = 2
        mutations.append(future)
        for index, mutation in enumerate(mutations):
            with self.subTest(index=index):
                with self.assertRaises(checker.MatrixValidationError):
                    checker.validate_matrix_document(mutation)

    def test_duplicate_keys_and_noncanonical_storage_fail_before_git_binding(
        self,
    ) -> None:
        duplicate_raw = b'{"matrix_id":"x","matrix_id":"y"}\n'
        with self.assertRaisesRegex(checker.MatrixValidationError, "duplicate"):
            checker._parse_canonical_document(duplicate_raw, "matrix")
        indented = (
            json.dumps(checker.expected_matrix(), indent=2).encode("utf-8") + b"\n"
        )
        with self.assertRaisesRegex(checker.MatrixValidationError, "canonical"):
            checker._parse_canonical_document(indented, "matrix")
        without_newline = checker.canonical_json_bytes(checker.expected_matrix())
        with self.assertRaisesRegex(checker.MatrixValidationError, "one newline"):
            checker._parse_canonical_document(without_newline, "matrix")

    def test_payload_commit_tree_blob_and_worktree_bytes_are_all_bound(self) -> None:
        second = self.root / "unrelated.txt"
        second.write_text("second\n")
        self._git("add", "unrelated.txt")
        self._git("commit", "-q", "-m", "second")
        second_commit = self._git("rev-parse", "HEAD").stdout.strip()
        second_tree = self._git("rev-parse", "HEAD^{tree}").stdout.strip()
        with self.assertRaisesRegex(checker.MatrixValidationError, "does not belong"):
            checker.validate_matrix_file(
                os.fspath(self.root),
                checker.MATRIX_RELATIVE_PATH.as_posix(),
                self.commit,
                second_tree,
                os.path.realpath("/usr/bin/git"),
            )
        mutated = copy.deepcopy(self.matrix_document)
        mutated["rows"][0]["expectedGeneration"] = 9
        self._write_matrix(mutated)
        with self.assertRaises(checker.MatrixValidationError):
            checker.validate_matrix_file(
                os.fspath(self.root),
                checker.MATRIX_RELATIVE_PATH.as_posix(),
                second_commit,
                second_tree,
                os.path.realpath("/usr/bin/git"),
            )

    def test_symlink_matrix_and_wrong_repository_relative_path_fail(self) -> None:
        real_matrix = self.base / "matrix-real.json"
        self.matrix_path.replace(real_matrix)
        self.matrix_path.symlink_to(real_matrix)
        with self.assertRaisesRegex(checker.MatrixValidationError, "symlink"):
            checker.validate_matrix_file(
                os.fspath(self.root),
                checker.MATRIX_RELATIVE_PATH.as_posix(),
                self.commit,
                self.tree,
                os.path.realpath("/usr/bin/git"),
            )
        self.matrix_path.unlink()
        real_matrix.replace(self.matrix_path)
        with self.assertRaisesRegex(
            checker.MatrixValidationError, "cannot be resolved|exactly"
        ):
            checker.validate_matrix_file(
                os.fspath(self.root),
                "different.json",
                self.commit,
                self.tree,
                os.path.realpath("/usr/bin/git"),
            )

    def write_evidence(self, documents: tuple[dict[str, object], ...]) -> list[str]:
        paths: list[str] = []
        for name, document in zip(
            ("trace", "archive", "reopen", "reachability"),
            documents,
        ):
            path = self.base / f"{name}.json"
            path.write_bytes(checker.canonical_json_bytes(document) + b"\n")
            paths.append(os.fspath(path))
        return paths

    def device_arguments(self, paths: list[str]) -> list[str]:
        return [
            *self.checker_arguments(),
            "--device-trace",
            paths[0],
            "--archive-attestation",
            paths[1],
            "--external-reopen-receipt",
            paths[2],
            "--production-reachability",
            paths[3],
        ]

    def bound_evidence(self) -> tuple[dict[str, object], ...]:
        return evidence_documents(
            self.commit,
            self.tree,
            hashlib.sha256(self.matrix_path.read_bytes()).hexdigest(),
        )

    def test_device_cli_requires_all_evidence_and_validates_complete_evidence(
        self,
    ) -> None:
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            result = checker.main(
                [*self.checker_arguments(), "--device-trace", "/private/tmp/trace.json"]
            )
        self.assertEqual(result, 2)
        self.assertIn("all four", stderr.getvalue())

        evidence_paths = self.write_evidence(self.bound_evidence())
        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            result = checker.main(self.device_arguments(evidence_paths))
        self.assertEqual(result, 0, stderr.getvalue())
        self.assertEqual(stderr.getvalue(), "")
        self.assertIn("PASS mode=device rows=40 assertions=9", stdout.getvalue())
        self.assertNotIn("mode=matrix", stdout.getvalue())

    def test_device_evidence_replay_skip_misbind_and_cleanup_residue_fail(self) -> None:
        mutations: list[tuple[str, tuple[dict[str, object], ...]]] = []
        documents = self.bound_evidence()
        skipped = copy.deepcopy(documents)
        skipped[0]["events"] = list(skipped[0]["events"])[:-1]
        mutations.append(("skip", skipped))

        documents = self.bound_evidence()
        replayed = copy.deepcopy(documents)
        replayed[1]["challengeDigest"] = "0" * 64
        mutations.append(("replay", replayed))

        documents = self.bound_evidence()
        misbound = copy.deepcopy(documents)
        misbound[2]["facts"] = copy.deepcopy(misbound[2]["facts"])
        misbound[2]["facts"]["recordRoot"] = "0" * 64
        mutations.append(("misbind", misbound))

        documents = self.bound_evidence()
        residue = copy.deepcopy(documents)
        residue[3]["custodyProof"] = copy.deepcopy(residue[3]["custodyProof"])
        residue[3]["custodyProof"]["residueFileCount"] = 1
        mutations.append(("residue", residue))

        for label, mutation in mutations:
            with self.subTest(label=label):
                paths = self.write_evidence(mutation)
                stdout = io.StringIO()
                stderr = io.StringIO()
                with redirect_stdout(stdout), redirect_stderr(stderr):
                    result = checker.main(self.device_arguments(paths))
                self.assertEqual(result, 1)
                self.assertEqual(stdout.getvalue(), "")
                self.assertNotIn("PASS", stderr.getvalue())

    def test_device_binding_reuses_only_the_git_verified_matrix_bytes(self) -> None:
        replacement = copy.deepcopy(self.matrix_document)
        replacement["rows"][0]["expectedGeneration"] = 9
        replacement_raw = checker.canonical_json_bytes(replacement) + b"\n"
        evidence = evidence_documents(
            self.commit,
            self.tree,
            hashlib.sha256(replacement_raw).hexdigest(),
        )
        evidence_paths = self.write_evidence(evidence)
        original_validate_payload_binding = checker._validate_payload_binding

        def replace_after_git_verification(*arguments: object) -> None:
            original_validate_payload_binding(*arguments)
            replacement_path = self.matrix_path.with_name("replacement-matrix.json")
            replacement_path.write_bytes(replacement_raw)
            os.replace(replacement_path, self.matrix_path)

        stdout = io.StringIO()
        stderr = io.StringIO()
        with mock.patch.object(
            checker,
            "_validate_payload_binding",
            side_effect=replace_after_git_verification,
        ):
            with redirect_stdout(stdout), redirect_stderr(stderr):
                result = checker.main(self.device_arguments(evidence_paths))

        self.assertEqual(result, 1)
        self.assertEqual(stdout.getvalue(), "")
        self.assertIn("candidate matrix", stderr.getvalue())
        self.assertNotIn("PASS", stderr.getvalue())


class ArtifactMeshDeviceRecoveryRunnerTests(GitMatrixFixture):
    def test_candidate_rejects_user_owned_replaceable_git_before_execution(
        self,
    ) -> None:
        executable, marker = self.replaceable_git("runner-replaceable-git")
        arguments = self.candidate_arguments()
        arguments[arguments.index("--git-executable") + 1] = os.fspath(executable)
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            result = runner.main(arguments)
        self.assertEqual(result, 2)
        self.assertFalse(marker.exists())
        self.assertIn("root-owned", stderr.getvalue())

    def exercise_protocol(
        self,
        lease: object,
        broker_response: object,
        custody_proof: object,
    ) -> tuple[dict[str, object], object, object]:
        lease_child, lease_peer = socket.socketpair(socket.AF_UNIX, socket.SOCK_STREAM)
        broker_child, broker_peer = socket.socketpair(
            socket.AF_UNIX, socket.SOCK_STREAM
        )
        custody_child, custody_peer = socket.socketpair(
            socket.AF_UNIX, socket.SOCK_STREAM
        )
        sockets = [
            lease_child,
            lease_peer,
            broker_child,
            broker_peer,
            custody_child,
            custody_peer,
        ]
        requests: dict[str, object] = {}
        provider_errors: list[BaseException] = []

        def provide(
            name: str,
            capability: socket.socket,
            response: object,
        ) -> None:
            try:
                requests[name] = receive_protocol_frame(capability)
                send_protocol_frame(capability, response)
            except BaseException as error:  # provider thread is test scaffolding
                provider_errors.append(error)

        send_protocol_frame(lease_peer, lease)
        broker_thread = threading.Thread(
            target=provide,
            args=("broker", broker_peer, broker_response),
            daemon=True,
        )
        custody_thread = threading.Thread(
            target=provide,
            args=("custody", custody_peer, custody_proof),
            daemon=True,
        )
        broker_thread.start()
        custody_thread.start()
        try:
            result = runner._run_protocol_sockets(
                lease_child,
                broker_child,
                custody_child,
            )
        finally:
            for item in sockets:
                item.close()
            broker_thread.join(timeout=2)
            custody_thread.join(timeout=2)
        if provider_errors:
            raise provider_errors[0]
        return result, requests["broker"], requests["custody"]

    def test_closed_capability_protocol_accepts_only_complete_cross_bound_evidence(
        self,
    ) -> None:
        lease, broker_response, custody_proof = protocol_fixture()
        result, broker_request, custody_request = self.exercise_protocol(
            lease,
            broker_response,
            custody_proof,
        )
        self.assertEqual(result["rowsValidated"], 40)
        self.assertEqual(result["assertionsValidated"], 9)
        self.assertEqual(result["terminal"], "custodyClosed")
        self.assertEqual(broker_request["leaseDigest"], broker_response["leaseDigest"])
        self.assertEqual(
            custody_request["brokerResponseDigest"],
            custody_proof["brokerResponseDigest"],
        )
        self.assertNotIn("success", result)
        self.assertNotIn("authority", result)

    def test_protocol_replay_misbind_skip_and_generic_success_fail_closed(self) -> None:
        mutations: list[
            tuple[str, dict[str, object], dict[str, object], dict[str, object]]
        ] = []

        lease, broker, custody = protocol_fixture()
        replay = copy.deepcopy(broker)
        replay["challengeDigest"] = "0" * 64
        mutations.append(("replay", lease, replay, custody))

        lease, broker, custody = protocol_fixture()
        skipped = copy.deepcopy(broker)
        skipped["events"] = list(skipped["events"])[:-1]
        mutations.append(("skip", lease, skipped, custody))

        lease, broker, custody = protocol_fixture()
        misbound = copy.deepcopy(custody)
        misbound["requestDigest"] = "0" * 64
        mutations.append(("misbind", lease, broker, misbound))

        lease, _, custody = protocol_fixture()
        mutations.append(("generic", lease, {"success": True}, custody))

        for label, lease, broker, custody in mutations:
            with self.subTest(label=label):
                with self.assertRaises(runner.ArtifactMeshDeviceRecoveryRunnerError):
                    self.exercise_protocol(lease, broker, custody)

    def test_protocol_missing_and_noncanonical_frames_fail_closed(self) -> None:
        lease_child, lease_peer = socket.socketpair(socket.AF_UNIX, socket.SOCK_STREAM)
        broker_child, broker_peer = socket.socketpair(
            socket.AF_UNIX, socket.SOCK_STREAM
        )
        custody_child, custody_peer = socket.socketpair(
            socket.AF_UNIX, socket.SOCK_STREAM
        )
        sockets = (
            lease_child,
            lease_peer,
            broker_child,
            broker_peer,
            custody_child,
            custody_peer,
        )
        self.addCleanup(lambda owned=sockets: [item.close() for item in owned])
        lease_peer.close()
        with self.assertRaisesRegex(
            runner.ArtifactMeshDeviceRecoveryRunnerError,
            "lease.*closed|lease.*missing",
        ):
            runner._run_protocol_sockets(lease_child, broker_child, custody_child)

        lease_child, lease_peer = socket.socketpair(socket.AF_UNIX, socket.SOCK_STREAM)
        broker_child, broker_peer = socket.socketpair(
            socket.AF_UNIX, socket.SOCK_STREAM
        )
        custody_child, custody_peer = socket.socketpair(
            socket.AF_UNIX, socket.SOCK_STREAM
        )
        sockets = (
            lease_child,
            lease_peer,
            broker_child,
            broker_peer,
            custody_child,
            custody_peer,
        )
        self.addCleanup(lambda owned=sockets: [item.close() for item in owned])
        raw = json.dumps(protocol_fixture()[0], indent=2).encode("utf-8")
        lease_peer.sendall(len(raw).to_bytes(8, "big") + raw)
        with self.assertRaisesRegex(
            runner.ArtifactMeshDeviceRecoveryRunnerError,
            "canonical",
        ):
            runner._run_protocol_sockets(lease_child, broker_child, custody_child)

    def test_protocol_silent_lease_hits_the_shared_absolute_deadline(self) -> None:
        lease_child, lease_peer = socket.socketpair(socket.AF_UNIX, socket.SOCK_STREAM)
        broker_child, broker_peer = socket.socketpair(
            socket.AF_UNIX, socket.SOCK_STREAM
        )
        custody_child, custody_peer = socket.socketpair(
            socket.AF_UNIX, socket.SOCK_STREAM
        )
        sockets = (
            lease_child,
            lease_peer,
            broker_child,
            broker_peer,
            custody_child,
            custody_peer,
        )
        self.addCleanup(lambda owned=sockets: [item.close() for item in owned])
        started = time.monotonic()
        errors: list[BaseException] = []

        def run_protocol() -> None:
            try:
                runner._run_protocol_sockets(
                    lease_child,
                    broker_child,
                    custody_child,
                    deadline=started + 0.05,
                )
            except BaseException as error:  # test wall-clock containment
                errors.append(error)

        thread = threading.Thread(target=run_protocol, daemon=True)
        thread.start()
        thread.join(timeout=1.0)
        if thread.is_alive():
            for capability in sockets:
                capability.close()
            thread.join(timeout=1.0)
        self.assertFalse(
            thread.is_alive(), "silent FD3 peer blocked past the test bound"
        )
        self.assertEqual(len(errors), 1)
        self.assertIsInstance(
            errors[0],
            runner.ArtifactMeshDeviceRecoveryRunnerError,
        )
        self.assertRegex(str(errors[0]), "FD3 lease.*deadline")
        self.assertLess(time.monotonic() - started, 1.0)

    def test_protocol_send_to_nonreading_peer_hits_the_absolute_deadline(self) -> None:
        writer, nonreading_peer = socket.socketpair(socket.AF_UNIX, socket.SOCK_STREAM)
        sockets = (writer, nonreading_peer)
        self.addCleanup(lambda owned=sockets: [item.close() for item in owned])
        writer.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 4096)
        document = {"payload": "x" * (8 * 1024 * 1024)}
        started = time.monotonic()
        errors: list[BaseException] = []

        def send_frame() -> None:
            try:
                runner._send_protocol_frame(
                    writer,
                    document,
                    "FD4 request",
                    deadline=started + 0.2,
                )
            except BaseException as error:  # test wall-clock containment
                errors.append(error)

        thread = threading.Thread(target=send_frame, daemon=True)
        thread.start()
        thread.join(timeout=1.0)
        if thread.is_alive():
            for capability in sockets:
                capability.close()
            thread.join(timeout=1.0)
        self.assertFalse(
            thread.is_alive(),
            "nonreading FD4 peer blocked past the test bound",
        )
        self.assertEqual(len(errors), 1)
        self.assertIsInstance(
            errors[0],
            runner.ArtifactMeshDeviceRecoveryRunnerError,
        )
        self.assertRegex(str(errors[0]), "FD4 request.*deadline")
        self.assertLess(time.monotonic() - started, 1.0)

    def test_fd3_fd4_fd5_share_one_monotonic_deadline(self) -> None:
        lease, broker_response, custody_proof = protocol_fixture()
        received = iter((lease, broker_response, custody_proof))
        observed: list[tuple[str, float]] = []

        def receive(
            _capability: object,
            label: str,
            deadline: float,
        ) -> object:
            observed.append((label, deadline))
            return next(received)

        def send(
            _capability: object,
            _document: object,
            label: str,
            deadline: float,
        ) -> None:
            observed.append((label, deadline))

        with (
            mock.patch.object(
                runner.time,
                "monotonic",
                side_effect=[410.25],
            ) as monotonic,
            mock.patch.object(
                runner,
                "_receive_protocol_frame",
                side_effect=receive,
            ),
            mock.patch.object(
                runner,
                "_send_protocol_frame",
                side_effect=send,
            ),
        ):
            result = runner._run_protocol_sockets(object(), object(), object())

        self.assertEqual(result["terminal"], "custodyClosed")
        self.assertEqual(monotonic.call_count, 1)
        self.assertEqual(
            observed,
            [
                ("FD3 lease", 440.25),
                ("FD4 request", 440.25),
                ("FD4 evidence", 440.25),
                ("FD5 request", 440.25),
                ("FD5 custody proof", 440.25),
            ],
        )

    def test_candidate_git_executable_is_required_exactly_once(self) -> None:
        arguments = self.candidate_arguments()
        del arguments[2:4]
        with redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(arguments), 2)
        arguments = [
            *self.candidate_arguments(),
            "--git-executable",
            os.path.realpath("/usr/bin/git"),
        ]
        with redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(arguments), 2)

    def test_candidate_git_is_bound_under_poisoned_path_and_rejects_invalid_tools(
        self,
    ) -> None:
        self.assertNotIn("PATH", runner.GIT_ENVIRONMENT)
        self.assertNotIn("PATH", checker.GIT_ENVIRONMENT)
        poison_directory = self.base / "runner-poison"
        poison_directory.mkdir()
        poison_git = poison_directory / "git"
        poison_git.write_text("#!/bin/sh\nexit 92\n", encoding="utf-8")
        poison_git.chmod(0o755)
        with mock.patch.dict(os.environ, {"PATH": os.fspath(poison_directory)}):
            with redirect_stderr(io.StringIO()):
                self.assertEqual(runner.main(self.candidate_arguments()), 22)

        nonexecutable = self.base / "nonexecutable-git"
        nonexecutable.write_text("#!/bin/sh\nexit 0\n", encoding="utf-8")
        symlink = self.base / "runner-git-link"
        symlink.symlink_to(os.path.realpath("/usr/bin/git"))
        directory = self.base / "runner-git-directory"
        directory.mkdir()
        for value in (
            "git",
            os.fspath(nonexecutable),
            os.fspath(symlink),
            os.fspath(directory),
        ):
            with self.subTest(value=value):
                arguments = self.candidate_arguments()
                arguments[arguments.index("--git-executable") + 1] = value
                with redirect_stderr(io.StringIO()):
                    self.assertEqual(runner.main(arguments), 2)

    def test_generator_is_independent_from_checker_and_matches_closed_corpus(
        self,
    ) -> None:
        checker_source = CHECKER_SCRIPT.read_text()
        runner_source = RUNNER_SCRIPT.read_text()
        self.assertNotIn("import check_artifact_mesh_device_recovery", runner_source)
        self.assertNotIn("from scripts import check_artifact", runner_source)
        self.assertNotIn("import run_artifact_mesh_device_recovery", checker_source)
        self.assertEqual(runner.generator_expected_matrix(), checker.expected_matrix())

        original = checker.NO_FAULT_EXPECTED["reopen"]["before"]
        try:
            checker.NO_FAULT_EXPECTED["reopen"]["before"] = (
                "drifted",
                "resume",
                0,
                0,
                0,
            )
            self.assertNotEqual(
                runner.generator_expected_matrix(), checker.expected_matrix()
            )
            self.assertEqual(
                runner.generator_expected_matrix()["rows"][6]["initialState"],
                "committedG0",
            )
        finally:
            checker.NO_FAULT_EXPECTED["reopen"]["before"] = original

    def test_candidate_preflight_is_non_authoritative_blocked_and_nonzero(self) -> None:
        stdout = io.StringIO()
        stderr = io.StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            result = runner.main(self.candidate_arguments())
        self.assertEqual(result, 22)
        self.assertEqual(stdout.getvalue(), "")
        self.assertIn("PHYSICAL_BROKER_REQUIRED", stderr.getvalue())
        self.assertIn("rows_executed=0", stderr.getvalue())
        disposition_path = self.output_directory / runner.DISPOSITION_NAME
        disposition = json.loads(disposition_path.read_text())
        self.assertEqual(disposition["authority"], "none")
        self.assertEqual(disposition["disposition"], "blockedPhysicalBrokerRequired")
        self.assertEqual(disposition["matrix_rows_validated"], 40)
        self.assertEqual(disposition["physical_rows_executed"], 0)
        self.assertFalse(
            {"success", "passed", "receipt", "admission"} & set(disposition)
        )

    def test_candidate_preflight_disposition_is_create_once(self) -> None:
        with redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(self.candidate_arguments()), 22)
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            self.assertEqual(runner.main(self.candidate_arguments()), 2)
        self.assertIn("cannot be written safely", stderr.getvalue())

    def test_candidate_and_production_cli_surfaces_are_disjoint(self) -> None:
        with self.assertRaisesRegex(
            runner.ArtifactMeshDeviceRecoveryRunnerError,
            "candidate-preflight",
        ):
            runner._dispatch_parser([*self.candidate_arguments(), "--lease-fd", "3"])
        with self.assertRaisesRegex(
            runner.ArtifactMeshDeviceRecoveryRunnerError,
            "production",
        ):
            runner._dispatch_parser(
                [
                    "--mode",
                    "production",
                    "--lease-fd",
                    "3",
                    "--physical-broker-fd",
                    "4",
                    "--custody-fd",
                    "5",
                    "--root",
                    os.fspath(self.root),
                ]
            )
        stderr = io.StringIO()
        with redirect_stderr(stderr):
            self.assertEqual(runner.main(["--mode=production"]), 2)
        self.assertIn("separate values", stderr.getvalue())

    def test_candidate_rejects_repository_output_and_wrong_matrix(self) -> None:
        arguments = self.candidate_arguments()
        arguments[-1] = os.fspath(self.root)
        with redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main(arguments), 2)
        mutated = copy.deepcopy(self.matrix_document)
        mutated["rows"][39]["expectedRecoveryFloor"] += 1
        self._write_matrix(mutated)
        with self.assertRaisesRegex(
            runner.ArtifactMeshDeviceRecoveryRunnerError,
            "independent corpus",
        ):
            runner._validate_candidate_matrix(
                Path(os.path.realpath("/usr/bin/git")),
                self.root,
                checker.MATRIX_RELATIVE_PATH.as_posix(),
                self.commit,
                self.tree,
            )

    def test_production_rejects_qinao_environment_before_capability_use(self) -> None:
        arguments = argparse_namespace_for_production()
        with mock.patch.dict(os.environ, {"QINAO_DEVICE": "forbidden"}, clear=False):
            with self.assertRaisesRegex(
                runner.ArtifactMeshDeviceRecoveryRunnerError,
                "QINAO_",
            ):
                runner.run_production(arguments)

    def test_production_fd_mode_never_invokes_git_or_a_subprocess(self) -> None:
        retained: list[int] = []
        peers: list[int] = []
        peer_sockets: list[socket.socket] = []
        provider_threads: list[threading.Thread] = []
        provider_errors: list[BaseException] = []
        saved_targets: dict[int, Optional[int]] = {}
        stdout = io.StringIO()
        try:
            for _ in range(3):
                first, second = socket.socketpair(socket.AF_UNIX, socket.SOCK_STREAM)
                retained.append(fcntl.fcntl(second.fileno(), fcntl.F_DUPFD_CLOEXEC, 20))
                peers.append(fcntl.fcntl(first.fileno(), fcntl.F_DUPFD_CLOEXEC, 40))
                first.close()
                second.close()
            for source, destination in zip(retained, (3, 4, 5)):
                try:
                    saved_targets[destination] = fcntl.fcntl(
                        destination,
                        fcntl.F_DUPFD_CLOEXEC,
                        30,
                    )
                except OSError:
                    saved_targets[destination] = None
                os.dup2(source, destination, inheritable=True)

            peer_sockets = [socket.socket(fileno=descriptor) for descriptor in peers]
            peers = []
            lease, broker_response, custody_proof = protocol_fixture()
            send_protocol_frame(peer_sockets[0], lease)

            def provide(capability: socket.socket, response: object) -> None:
                try:
                    receive_protocol_frame(capability)
                    send_protocol_frame(capability, response)
                except BaseException as error:
                    provider_errors.append(error)

            for capability, response in (
                (peer_sockets[1], broker_response),
                (peer_sockets[2], custody_proof),
            ):
                thread = threading.Thread(
                    target=provide,
                    args=(capability, response),
                    daemon=True,
                )
                provider_threads.append(thread)
                thread.start()

            forbidden = AssertionError(
                "production FD mode attempted Git or subprocess execution"
            )
            with (
                mock.patch.object(
                    runner,
                    "_run_git",
                    side_effect=forbidden,
                ),
                mock.patch.object(
                    runner.subprocess,
                    "run",
                    side_effect=forbidden,
                ),
                mock.patch.object(
                    runner.subprocess,
                    "Popen",
                    side_effect=forbidden,
                ),
                redirect_stdout(stdout),
            ):
                result = runner.run_production(argparse_namespace_for_production())
            for thread in provider_threads:
                thread.join(timeout=2)
        finally:
            for destination, saved in saved_targets.items():
                if saved is None:
                    try:
                        os.close(destination)
                    except OSError:
                        pass
                else:
                    os.dup2(saved, destination)
                    os.close(saved)
            for descriptor in retained:
                os.close(descriptor)
            for descriptor in peers:
                os.close(descriptor)
            for capability in peer_sockets:
                capability.close()
        self.assertEqual(provider_errors, [])
        self.assertEqual(result, 0)
        self.assertIn("PASS mode=device rows=40 assertions=9", stdout.getvalue())

    def test_regular_descriptor_is_not_a_non_path_capability(self) -> None:
        regular = self.base / "capability-lookalike"
        regular.write_bytes(b"not a capability")
        descriptor = os.open(regular, os.O_RDONLY)
        self.addCleanup(os.close, descriptor)
        with self.assertRaisesRegex(
            runner.ArtifactMeshDeviceRecoveryRunnerError,
            "non-path socket",
        ):
            runner._require_capability_socket(descriptor, descriptor, "test")

    def testProductionControllerRequiresImplementedRunner(self) -> None:
        retained: list[int] = []
        peers: list[int] = []
        peer_sockets: list[socket.socket] = []
        provider_threads: list[threading.Thread] = []
        provider_errors: list[BaseException] = []
        saved_targets: dict[int, Optional[int]] = {}
        try:
            for _ in range(3):
                first, second = socket.socketpair(socket.AF_UNIX, socket.SOCK_STREAM)
                retained.append(fcntl.fcntl(second.fileno(), fcntl.F_DUPFD_CLOEXEC, 20))
                peers.append(fcntl.fcntl(first.fileno(), fcntl.F_DUPFD_CLOEXEC, 40))
                first.close()
                second.close()
            for source, destination in zip(retained, (3, 4, 5)):
                try:
                    saved_targets[destination] = fcntl.fcntl(
                        destination,
                        fcntl.F_DUPFD_CLOEXEC,
                        30,
                    )
                except OSError:
                    saved_targets[destination] = None
                os.dup2(source, destination, inheritable=True)

            peer_sockets = [socket.socket(fileno=descriptor) for descriptor in peers]
            peers = []
            lease, broker_response, custody_proof = protocol_fixture()
            send_protocol_frame(peer_sockets[0], lease)

            def provide(capability: socket.socket, response: object) -> None:
                try:
                    receive_protocol_frame(capability)
                    send_protocol_frame(capability, response)
                except BaseException as error:
                    provider_errors.append(error)

            for capability, response in (
                (peer_sockets[1], broker_response),
                (peer_sockets[2], custody_proof),
            ):
                thread = threading.Thread(
                    target=provide,
                    args=(capability, response),
                    daemon=True,
                )
                provider_threads.append(thread)
                thread.start()

            completed = subprocess.run(
                [
                    sys.executable,
                    os.fspath(RUNNER_SCRIPT),
                    "--mode",
                    "production",
                    "--lease-fd",
                    "3",
                    "--physical-broker-fd",
                    "4",
                    "--custody-fd",
                    "5",
                ],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                env={
                    key: value
                    for key, value in os.environ.items()
                    if not key.startswith("QINAO_")
                },
                pass_fds=(3, 4, 5),
                check=False,
                timeout=10,
            )
            for thread in provider_threads:
                thread.join(timeout=2)
        finally:
            for destination, saved in saved_targets.items():
                if saved is None:
                    try:
                        os.close(destination)
                    except OSError:
                        pass
                else:
                    os.dup2(saved, destination)
                    os.close(saved)
            for descriptor in retained:
                os.close(descriptor)
            for descriptor in peers:
                os.close(descriptor)
            for capability in peer_sockets:
                capability.close()
        self.assertEqual(provider_errors, [])
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertIn("PASS mode=device rows=40 assertions=9", completed.stdout)
        self.assertEqual(completed.stderr, "")
        self.assertNotIn("authority", completed.stdout)


def argparse_namespace_for_production() -> object:
    return type(
        "ProductionArguments",
        (),
        {"lease_fd": 3, "physical_broker_fd": 4, "custody_fd": 5},
    )()


if __name__ == "__main__":
    unittest.main()
