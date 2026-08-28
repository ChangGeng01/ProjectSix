from __future__ import annotations

import base64
import copy
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

from scripts import prepare_qinao_v2_wave_candidate as prepare
from scripts.test_check_qinao_owner_ledger import (
    _canonical_test_json,
    _test_ed25519_sign,
    _test_governance_signature_preimage,
    _test_scoped_trust_key,
)
from scripts import test_run_qinao_wave_admission as wave_test_helpers


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER = PROJECT_ROOT / "scripts" / "prepare_qinao_v2_wave_candidate.py"
TARGET_REF = "refs/heads/codex/qinao-admitted-controlled-convergence"
W1_SLICE = "w1.artifact-mesh-contract-freeze"
W1_MESSAGE = "feat(qinao): restore mesh and freeze automation contracts"
V2_SCOPE = "QinaoWaveAdmissionReceiptV2"
V2_KEY_ID = "test-only-QinaoWaveAdmissionReceiptV2-key"
V2_SEED = b"\x91" * 32
TERMINAL_ROOT_DOMAIN = b"QINAO-LEDGER-V2-MIGRATION-TERMINAL-ROOT-V1\x00"
TEST_GIT = Path("/usr/bin/git").resolve(strict=True)
REPOSITORY_IDENTITY = wave_test_helpers.REPOSITORY_IDENTITY
W2_SLICE = "w2.state-and-retention"
W2_MESSAGE = "feat(qinao): extend K3 for governed automation and retention"

TEST_PROTECTED_CANDIDATE_FIELDS = {
    "admissionKind",
    "admissionStatus",
    "assertionRowsRoot",
    "authorizingOwnerLedgerBlobDigest",
    "baseCommit",
    "baseTree",
    "bootstrapCommit",
    "bootstrapTree",
    "candidateCommit",
    "candidateTree",
    "commandRowsRoot",
    "descendantProfilesRoot",
    "evidenceRetentionDurationSeconds",
    "evidenceRetentionPolicyRoot",
    "externalInputRequirementRowsRoot",
    "hardResourceCapsRoot",
    "kind",
    "operationID",
    "operationInstanceKey",
    "outcome",
    "policyAuthorizationRoot",
    "policyRoot",
    "preparedRefName",
    "refExpectedOldOID",
    "runtimeProfileID",
    "runtimeProfileRoot",
    "targetOwnerLedgerBlobDigest",
    "targetRefName",
    "toolRowsRoot",
    "waveSliceID",
}

TEST_PROTECTED_VALIDATION_FIELDS = {
    "admissionKind",
    "assertionCount",
    "assertionResultsRoot",
    "assertionRowsRoot",
    "authorizationCoreRoot",
    "authorizingOwnerLedgerBlobDigest",
    "baseCommit",
    "baseTree",
    "bootstrapCommit",
    "bootstrapTree",
    "candidateCommit",
    "candidateTree",
    "challengeConsumptionRoot",
    "challengeConsumptionStoredByteLength",
    "challengeConsumptionStoredSHA256",
    "challengeDigest",
    "challengeExpiresAt",
    "challengeIssuedAt",
    "commandRowsRoot",
    "commandTerminalRowsRoot",
    "descendantProfilesRoot",
    "evidenceRetentionDurationSeconds",
    "evidenceRetentionLeaseRoot",
    "evidenceRetentionLeaseStoredByteLength",
    "evidenceRetentionLeaseStoredSHA256",
    "evidenceRetentionPolicyRoot",
    "evidenceRowsRoot",
    "externalInputRequirementRowsRoot",
    "externalInputRowsRoot",
    "fencingTokenDigest",
    "finalizingEpoch",
    "hardResourceCapsRoot",
    "jobTerminalRoot",
    "jobTerminalStoredByteLength",
    "jobTerminalStoredSHA256",
    "kind",
    "operationAuthorizationRoot",
    "operationID",
    "operationInstanceKey",
    "outcome",
    "policyAuthorizationRoot",
    "policyRoot",
    "preparedRefName",
    "previousRunControlHeadRoot",
    "refExpectedOldOID",
    "requiredEvidenceRetentionNotBefore",
    "resultObjectRoot",
    "resultRowsRoot",
    "resultStoredByteLength",
    "resultStoredSHA256",
    "runAttemptID",
    "runAuthorizationRoot",
    "runClaimSetRoot",
    "runClaimSetStoredByteLength",
    "runClaimSetStoredSHA256",
    "runContextRoot",
    "runControlKey",
    "runFinalizationReceiptRoot",
    "runFinalizationReceiptStoredByteLength",
    "runFinalizationReceiptStoredSHA256",
    "runtimeProfileID",
    "runtimeProfileRoot",
    "targetOwnerLedgerBlobDigest",
    "targetRefName",
    "toolRowsRoot",
    "validationPayloadRoot",
    "verifiedAt",
    "waveSliceID",
}


def terminal_root(document: dict) -> str:
    unsigned = copy.deepcopy(document)
    unsigned.pop("terminalRoot", None)
    return hashlib.sha256(
        TERMINAL_ROOT_DOMAIN + _canonical_test_json(unsigned)
    ).hexdigest()


class PrepareQinaoV2WaveCandidateTests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        fixture = wave_test_helpers.WaveAdmissionRunnerTests(methodName="runTest")
        fixture.setUp()
        self.addCleanup(fixture.doCleanups)
        self.fixture = fixture
        self.root = fixture.root
        self.external = fixture.external
        self.original_commit = fixture.base_commit
        self.original_tree = fixture.base_tree

        self.git("reset", "--hard", self.original_commit)
        self.git("branch", "-M", TARGET_REF.removeprefix("refs/heads/"))

        trust_root = copy.deepcopy(fixture.trust_root)
        trust_root["keys"].append(
            _test_scoped_trust_key(
                V2_SEED,
                V2_KEY_ID,
                "wave-admission-signer",
                V2_SCOPE,
            )
        )
        trust_root["keys"] = sorted(
            trust_root["keys"],
            key=_canonical_test_json,
        )
        self.trust_root = trust_root
        self.write_external(fixture.trust_path, trust_root)

        migration_path = self.root / "docs" / "evidence" / "migration.txt"
        migration_path.parent.mkdir(parents=True, exist_ok=True)
        migration_path.write_text("installed ledger-v2 migration\n", encoding="utf-8")
        ledger_path = "docs/superpowers/specs/qinao-owner-ledger-v1.json"
        ledger_file = self.root / ledger_path
        ledger_file.parent.mkdir(parents=True, exist_ok=True)
        ledger_file.write_text("{}\n", encoding="utf-8")
        self.git(
            "add",
            migration_path.relative_to(self.root).as_posix(),
            ledger_path,
        )
        self.git("commit", "-qm", "test-only installed ledger-v2 migration")
        self.base_commit = self.git("rev-parse", "HEAD")
        self.base_tree = self.git("rev-parse", "HEAD^{tree}")

        ledger_blob = self.git("rev-parse", f"{self.base_tree}:{ledger_path}")
        ledger_bytes = self.git_bytes("cat-file", "blob", ledger_blob)
        root_receipt_bytes = _canonical_test_json(fixture.previous_receipt) + b"\n"
        migration_terminal = {
            "schema": "QinaoLedgerV2MigrationTerminalReceiptV1",
            "repositoryIdentity": REPOSITORY_IDENTITY,
            "operationID": "bootstrap.ledger-v2-migration",
            "operationInstanceKey": "1" * 64,
            "predecessorCommit": self.original_commit,
            "predecessorTree": self.original_tree,
            "predecessorRootReceiptDigest": hashlib.sha256(
                root_receipt_bytes
            ).hexdigest(),
            "predecessorReceiptStoredSHA256": hashlib.sha256(
                root_receipt_bytes
            ).hexdigest(),
            "predecessorReceiptClosureRoot": "2" * 64,
            "candidateCommit": self.base_commit,
            "candidateTree": self.base_tree,
            "targetRefName": TARGET_REF,
            "preparedRefName": "refs/qinao/prepared/ledger-v2/test-only",
            "refExpectedOldOID": self.original_commit,
            "refInstalledOID": self.base_commit,
            "refCASResultRoot": "3" * 64,
            "authorizationCoreRoot": "4" * 64,
            "operationAuthorizationRoot": "5" * 64,
            "policyAuthorizationRoot": "6" * 64,
            "baseOwnerLedgerBlobDigest": "7" * 64,
            "targetOwnerLedgerBlobDigest": "8" * 64,
            "targetProtectedPolicyRoot": "9" * 64,
            "protectedResultStoredByteLength": 17,
            "protectedResultStoredSHA256": "a" * 64,
            "validationPayloadRoot": "b" * 64,
            "resultRowsRoot": "c" * 64,
            "jobTerminalRoot": "d" * 64,
            "challengeDigest": "e" * 64,
            "runAttemptID": "test-only-ledger-v2-run-attempt",
            "challengeConsumptionRoot": "f" * 64,
            "evidenceRetentionLeaseStoredByteLength": 23,
            "evidenceRetentionLeaseStoredSHA256": "1" * 64,
            "evidenceRetentionLeaseRoot": "2" * 64,
            "runFinalizationReceiptStoredByteLength": 29,
            "runFinalizationReceiptStoredSHA256": "3" * 64,
            "runFinalizationReceiptRoot": "4" * 64,
            "installedOwnerLedgerPath": ledger_path,
            "installedOwnerLedgerGitBlobOID": ledger_blob,
            "installedOwnerLedgerStoredSHA256": hashlib.sha256(
                ledger_bytes
            ).hexdigest(),
            "controllerTransactionID": "test-only-ledger-v2-controller",
            "committedAt": "2026-07-30T00:00:00Z",
            "state": "installed",
            "outcome": "passed",
        }
        migration_terminal["terminalRoot"] = terminal_root(migration_terminal)
        self.previous_receipt = migration_terminal
        self.write_external(fixture.previous_path, migration_terminal)

        self.changed_relative = "Sources/Candidate.txt"
        self.path_list_relative = "docs/evidence/w1-paths.txt"
        changed = self.root / self.changed_relative
        changed.parent.mkdir(parents=True, exist_ok=True)
        changed.write_text("candidate bytes\n", encoding="utf-8")
        self.path_list_path = self.root / self.path_list_relative
        self.path_list_path.parent.mkdir(parents=True, exist_ok=True)
        self.path_list_path.write_text(
            f"{self.changed_relative}\n{self.path_list_relative}\n",
            encoding="utf-8",
        )
        self.git("add", self.changed_relative, self.path_list_relative)
        self.candidate_tree = self.git("write-tree")

    def git(self, *arguments: str, check: bool = True) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            check=check,
            capture_output=True,
            text=True,
        ).stdout.strip()

    def git_bytes(self, *arguments: str) -> bytes:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.root,
            check=True,
            capture_output=True,
        ).stdout

    @staticmethod
    def write_external(path: Path, document: dict) -> None:
        path.write_bytes(_canonical_test_json(document) + b"\n")
        path.chmod(0o600)

    def command(
        self,
        *,
        candidate_tree: str | None = None,
        wave: str = "W1",
        wave_slice_id: str = W1_SLICE,
        sequence_ordinal: int = 1,
        commit_message: str = W1_MESSAGE,
        previous_receipt: Path | None = None,
        git_executable: Path = TEST_GIT,
    ) -> list[str]:
        return [
            sys.executable,
            str(RUNNER),
            "--root",
            str(self.root),
            "--git-executable",
            str(git_executable),
            "--source-selection",
            str(self.fixture.selection_path),
            "--trust-root",
            str(self.fixture.trust_path),
            "--previous-receipt",
            str(previous_receipt or self.fixture.previous_path),
            "--candidate-tree",
            candidate_tree or self.candidate_tree,
            "--candidate-path-list",
            str(self.path_list_path),
            "--wave",
            wave,
            "--wave-slice-id",
            wave_slice_id,
            "--sequence-ordinal",
            str(sequence_ordinal),
            "--commit-message",
            commit_message,
        ]

    def run_prepare(
        self,
        *,
        environment: dict[str, str] | None = None,
        **command_overrides: object,
    ) -> subprocess.CompletedProcess[str]:
        effective_environment = dict(os.environ)
        effective_environment["PYTHONDONTWRITEBYTECODE"] = "1"
        if environment:
            effective_environment.update(environment)
        return subprocess.run(
            self.command(**command_overrides),
            cwd=self.root,
            env=effective_environment,
            capture_output=True,
            text=True,
        )

    def run_raw(self, arguments: list[str]) -> subprocess.CompletedProcess[str]:
        environment = dict(os.environ)
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        return subprocess.run(
            [sys.executable, str(RUNNER), *arguments],
            cwd=self.root,
            env=environment,
            capture_output=True,
            text=True,
        )

    def expected_prepared_ref(self) -> str:
        identity = [
            REPOSITORY_IDENTITY,
            TARGET_REF,
            W1_SLICE,
            1,
            self.base_commit,
            self.candidate_tree,
        ]
        digest = hashlib.sha256(_canonical_test_json(identity)).hexdigest()
        return f"refs/qinao/prepared/wave-v2/{digest}"

    def parse_success(self, completed: subprocess.CompletedProcess[str]) -> list[str]:
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(completed.stderr, "")
        self.assertTrue(completed.stdout.endswith("\n"))
        self.assertEqual(completed.stdout.count("\n"), 1)
        values = completed.stdout.removesuffix("\n").split("\t")
        self.assertEqual(len(values), 5)
        return values

    def signed_v2_w1_receipt(
        self,
        *,
        base_commit: str,
        base_tree: str,
        candidate_commit: str,
        candidate_tree: str,
        prepared_ref: str,
    ) -> dict:
        operation_key = "0" * 64
        candidate = {field: "a" * 64 for field in TEST_PROTECTED_CANDIDATE_FIELDS}
        candidate.update(
            {
                "kind": "productionCandidate",
                "operationID": W1_SLICE,
                "admissionKind": "waveAdmission",
                "waveSliceID": W1_SLICE,
                "operationInstanceKey": operation_key,
                "targetRefName": TARGET_REF,
                "preparedRefName": prepared_ref,
                "refExpectedOldOID": base_commit,
                "baseCommit": base_commit,
                "baseTree": base_tree,
                "bootstrapCommit": base_commit,
                "bootstrapTree": base_tree,
                "candidateCommit": candidate_commit,
                "candidateTree": candidate_tree,
                "runtimeProfileID": "test-only-runtime-profile",
                "evidenceRetentionDurationSeconds": 259200,
                "authorizingOwnerLedgerBlobDigest": "1" * 64,
                "targetOwnerLedgerBlobDigest": "2" * 64,
                "policyRoot": "3" * 64,
                "admissionStatus": "unadmitted",
                "outcome": "candidateReady",
            }
        )
        validation = {field: "b" * 64 for field in TEST_PROTECTED_VALIDATION_FIELDS}
        validation.update(
            {
                "kind": "productionWave",
                "operationID": W1_SLICE,
                "admissionKind": "waveAdmission",
                "waveSliceID": W1_SLICE,
                "operationInstanceKey": operation_key,
                "targetRefName": TARGET_REF,
                "preparedRefName": prepared_ref,
                "refExpectedOldOID": base_commit,
                "baseCommit": base_commit,
                "baseTree": base_tree,
                "bootstrapCommit": base_commit,
                "bootstrapTree": base_tree,
                "candidateCommit": candidate_commit,
                "candidateTree": candidate_tree,
                "runtimeProfileID": "test-only-runtime-profile",
                "authorizingOwnerLedgerBlobDigest": "1" * 64,
                "targetOwnerLedgerBlobDigest": "2" * 64,
                "policyRoot": "3" * 64,
                "challengeIssuedAt": "2026-07-30T00:00:00Z",
                "challengeExpiresAt": "2026-07-30T00:05:00Z",
                "requiredEvidenceRetentionNotBefore": "2026-08-02T00:05:00Z",
                "verifiedAt": "2026-07-30T00:01:00Z",
                "runAttemptID": "test-only-w1-run-attempt",
                "runControlKey": "test-only-w1-run-control",
                "finalizingEpoch": 1,
                "assertionCount": 1,
                "runClaimSetStoredByteLength": 10,
                "challengeConsumptionStoredByteLength": 11,
                "resultStoredByteLength": 12,
                "jobTerminalStoredByteLength": 13,
                "evidenceRetentionLeaseStoredByteLength": 14,
                "runFinalizationReceiptStoredByteLength": 15,
                "evidenceRetentionDurationSeconds": 259200,
                "outcome": "passed",
            }
        )
        receipt = {
            "schema": "QinaoWaveAdmissionReceiptV2",
            "repositoryIdentity": REPOSITORY_IDENTITY,
            "wave": "W1",
            "waveSliceID": W1_SLICE,
            "sequenceOrdinal": 1,
            "baseCommit": base_commit,
            "baseTree": base_tree,
            "candidateTree": candidate_tree,
            "bundleBlobDigest": "1" * 64,
            "sourceSelectionBlobDigest": hashlib.sha256(
                self.fixture.selection_path.read_bytes()
            ).hexdigest(),
            "trustRootBlobDigest": hashlib.sha256(
                self.fixture.trust_path.read_bytes()
            ).hexdigest(),
            "previousReceiptBlobDigest": hashlib.sha256(
                self.fixture.previous_path.read_bytes()
            ).hexdigest(),
            "approvedDesignBlob": self.fixture.approved_design_sha256,
            "productionDiffRoot": "2" * 64,
            "pathList": {"root": "3" * 64, "count": 2},
            "ownerLedger": {
                "path": "docs/superpowers/specs/qinao-owner-ledger-v1.json",
                "blobDigest": "4" * 64,
            },
            "categories": {
                category: {
                    "blobDigest": str(index) * 64,
                    "reviewedRowsRoot": "5" * 64,
                    "rowCount": 0,
                    "status": "notApplicable",
                }
                for index, category in enumerate(
                    ("adapter", "create", "extension", "fixture"),
                    start=6,
                )
            },
            "evidencePrerequisites": [],
            "externalPrerequisites": [],
            "frozenSchemaDigests": [],
            "toolBlobs": {
                "bundleReviewSigningProvider": "a" * 64,
                "externalVerifier": "b" * 64,
                "ownerLedgerChecker": {
                    "path": "scripts/check_qinao_owner_ledger.py",
                    "blobDigest": "c" * 64,
                },
                "repositoryRunner": {
                    "path": "scripts/run_qinao_wave_admission.py",
                    "blobDigest": "d" * 64,
                },
                "waveAdmissionSigningProvider": "e" * 64,
            },
            "fixtureProof": {"root": "f" * 64, "count": 0},
            "protectedCommandPolicy": {
                "authorizingOwnerLedgerBlobDigest": "1" * 64,
                "targetOwnerLedgerBlobDigest": "2" * 64,
                "policyRoot": "3" * 64,
            },
            "protectedCandidateObservation": candidate,
            "protectedValidationObservation": validation,
            "targetRefInstallation": {
                "operationInstanceKey": operation_key,
                "targetRefName": TARGET_REF,
                "preparedRefName": prepared_ref,
                "refExpectedOldOID": base_commit,
                "refInstalledOID": candidate_commit,
                "refCASResultRoot": "4" * 64,
                "installedCommit": candidate_commit,
                "installedTree": candidate_tree,
                "reopenedOwnerLedgerBlobDigest": "2" * 64,
                "preparedRefDisposition": "deleted",
                "preparedRefDeleteCASResultRoot": "5" * 64,
                "controllerTransactionID": "test-only-w1-controller",
                "installedAt": "2026-07-30T00:02:00Z",
                "state": "installed",
                "outcome": "passed",
            },
            "verifiedAt": "2026-07-30T00:03:00Z",
            "outcome": "admitted",
            "issuedAt": "2026-07-30T00:03:00Z",
            "expiresAt": wave_test_helpers.EXPIRES_AT,
            "nonce": "test-only-w1-v2-receipt",
            "signer": V2_KEY_ID,
            "role": "wave-admission-signer",
            "signatureAlgorithm": "Ed25519",
        }
        receipt["signature"] = base64.b64encode(
            _test_ed25519_sign(
                V2_SEED,
                _test_governance_signature_preimage(receipt),
            )
        ).decode("ascii")
        return receipt

    def install_w1_and_stage_w2(self) -> tuple[list[str], Path]:
        w1_values = self.parse_success(self.run_prepare())
        self.git("update-ref", TARGET_REF, w1_values[3], self.base_commit)
        self.git("update-ref", "-d", w1_values[4], w1_values[3])
        self.git("reset", "--hard", w1_values[3])
        receipt = self.signed_v2_w1_receipt(
            base_commit=self.base_commit,
            base_tree=self.base_tree,
            candidate_commit=w1_values[3],
            candidate_tree=self.candidate_tree,
            prepared_ref=w1_values[4],
        )
        receipt_path = self.external / "w1-v2-receipt.json"
        self.write_external(receipt_path, receipt)

        self.changed_relative = "Sources/W2Candidate.txt"
        self.path_list_relative = "docs/evidence/w2-paths.txt"
        changed = self.root / self.changed_relative
        changed.write_text("w2 candidate bytes\n", encoding="utf-8")
        self.path_list_path = self.root / self.path_list_relative
        self.path_list_path.write_text(
            f"{self.changed_relative}\n{self.path_list_relative}\n",
            encoding="utf-8",
        )
        self.git("add", self.changed_relative, self.path_list_relative)
        self.candidate_tree = self.git("write-tree")
        return w1_values, receipt_path

    def test_v2_wave_prepares_candidate_commit_before_bundle_review(self) -> None:
        values = self.parse_success(self.run_prepare())

        self.assertEqual(
            self.git("rev-parse", values[3] + "^{tree}"), self.candidate_tree
        )
        self.assertEqual(self.git("show-ref", "--hash", values[4]), values[3])

    def test_v2_wave_candidate_commit_has_exact_parent_tree_and_metadata(self) -> None:
        values = self.parse_success(self.run_prepare())
        base_timestamp = int(self.git("show", "-s", "--format=%ct", self.base_commit))
        expected_timestamp = base_timestamp + 1
        expected = (
            f"tree {self.candidate_tree}\n"
            f"parent {self.base_commit}\n"
            "author Qinao Wave Candidate "
            f"<qinao-wave-candidate@invalid> {expected_timestamp} +0000\n"
            "committer Qinao Wave Candidate "
            f"<qinao-wave-candidate@invalid> {expected_timestamp} +0000\n"
            f"\n{W1_MESSAGE}\n"
        ).encode("utf-8")

        self.assertEqual(self.git_bytes("cat-file", "commit", values[3]), expected)

    def test_preparation_stdout_derives_all_five_identity_values(self) -> None:
        values = self.parse_success(self.run_prepare())

        self.assertEqual(
            values,
            [
                TARGET_REF,
                self.base_commit,
                self.base_tree,
                values[3],
                self.expected_prepared_ref(),
            ],
        )
        self.assertRegex(values[3], r"^[0-9a-f]{40}$")

    def test_v2_wave_prepared_ref_reuses_exact_commit(self) -> None:
        first = self.parse_success(self.run_prepare())
        object_path = self.root / ".git" / "objects" / first[3][:2] / first[3][2:]
        ref_path = self.root / ".git" / first[4]
        before = (object_path.stat().st_mtime_ns, ref_path.stat().st_mtime_ns)

        second = self.parse_success(self.run_prepare())

        self.assertEqual(second, first)
        self.assertEqual(
            (object_path.stat().st_mtime_ns, ref_path.stat().st_mtime_ns),
            before,
        )

    def test_v2_prepared_ref_namespace_binds_inherited_target_ref(self) -> None:
        values = self.parse_success(self.run_prepare())

        self.assertEqual(values[4], self.expected_prepared_ref())

    def test_v2_wave_conflicting_prepared_ref_or_detached_head_blocks(self) -> None:
        prepared_ref = self.expected_prepared_ref()
        alternative = subprocess.run(
            ["git", "commit-tree", self.candidate_tree, "-p", self.base_commit],
            cwd=self.root,
            input="conflicting candidate\n",
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
        self.git("update-ref", prepared_ref, alternative)

        conflict = self.run_prepare()

        self.assertEqual(conflict.returncode, 5)
        self.assertEqual(self.git("show-ref", "--hash", prepared_ref), alternative)
        self.assertEqual(self.git("show-ref", "--hash", TARGET_REF), self.base_commit)

    def test_detached_head_blocks_before_object_or_ref_creation(self) -> None:
        self.git("checkout", "--detach", "-q", self.base_commit)

        completed = self.run_prepare()

        self.assertEqual(completed.returncode, 3)
        self.assertNotEqual(
            self.git(
                "show-ref",
                "--verify",
                "--quiet",
                self.expected_prepared_ref(),
                check=False,
            ),
            "0",
        )

    def test_v2_wave_prepared_ref_never_confers_authority(self) -> None:
        before_target = self.git("show-ref", "--hash", TARGET_REF)
        before_head = self.git("rev-parse", "HEAD")
        before_index = self.git("write-tree")
        before_status = self.git_bytes("status", "--porcelain=v2", "-z")
        before_external = sorted(path.name for path in self.external.iterdir())

        values = self.parse_success(self.run_prepare())

        self.assertEqual(self.git("show-ref", "--hash", TARGET_REF), before_target)
        self.assertEqual(self.git("rev-parse", "HEAD"), before_head)
        self.assertEqual(self.git("write-tree"), before_index)
        self.assertEqual(
            self.git_bytes("status", "--porcelain=v2", "-z"), before_status
        )
        self.assertEqual(
            sorted(path.name for path in self.external.iterdir()),
            before_external,
        )
        self.assertEqual(self.git("show-ref", "--hash", values[4]), values[3])

    def test_target_ref_drift_blocks_before_prepared_ref_creation(self) -> None:
        self.git("update-ref", TARGET_REF, self.original_commit, self.base_commit)

        completed = self.run_prepare()

        self.assertEqual(completed.returncode, 3)
        self.assertEqual(
            self.git("show-ref", "--hash", TARGET_REF), self.original_commit
        )
        self.assertEqual(
            self.git("show-ref", "--verify", self.expected_prepared_ref(), check=False),
            "",
        )

    def test_candidate_path_list_must_equal_tree_and_staged_diff(self) -> None:
        self.path_list_path.write_text(
            f"{self.path_list_relative}\n",
            encoding="utf-8",
        )
        self.git("add", self.path_list_relative)
        mismatched_tree = self.git("write-tree")

        completed = self.run_prepare(candidate_tree=mismatched_tree)

        self.assertEqual(completed.returncode, 3)
        self.assertIn("path", completed.stderr.lower())

    def test_unstaged_candidate_path_blocks_before_write(self) -> None:
        (self.root / self.changed_relative).write_text(
            "candidate bytes changed after staging\n",
            encoding="utf-8",
        )

        completed = self.run_prepare()

        self.assertEqual(completed.returncode, 3)
        self.assertIn("unstaged", completed.stderr.lower())

    def test_unsafe_git_environment_override_is_rejected(self) -> None:
        completed = self.run_prepare(
            environment={"GIT_INDEX_FILE": str(self.root / ".git" / "index")}
        )

        self.assertEqual(completed.returncode, 3)
        self.assertIn("GIT_INDEX_FILE", completed.stderr)

    def test_explicit_git_binding_ignores_poisoned_path(self) -> None:
        completed = self.run_prepare(environment={"PATH": "/definitely/not/git"})

        self.parse_success(completed)

    def test_git_executable_must_be_absolute_canonical_regular_nonsymlink(self) -> None:
        link = self.external / "git-link"
        link.symlink_to(TEST_GIT)

        completed = self.run_prepare(git_executable=link)

        self.assertEqual(completed.returncode, 3)
        self.assertIn("--git-executable", completed.stderr)

    def test_git_executable_rejects_user_replaceable_binary_before_execution(
        self,
    ) -> None:
        replaceable_git = self.external / "replaceable-git"
        shutil.copyfile(TEST_GIT, replaceable_git)
        replaceable_git.chmod(0o755)

        completed = self.run_prepare(
            git_executable=replaceable_git.resolve(strict=True)
        )

        self.assertEqual(completed.returncode, 3)
        self.assertIn("root-owned", completed.stderr)
        self.assertIn("non-writable", completed.stderr)

    def test_closed_cli_rejects_abbreviated_option(self) -> None:
        arguments = self.command()[2:]
        index = arguments.index("--candidate-tree")
        arguments[index] = "--candidate-t"

        completed = self.run_raw(arguments)

        self.assertEqual(completed.returncode, 2)
        self.assertIn("abbreviat", completed.stderr.lower())

    def test_closed_cli_rejects_duplicate_option(self) -> None:
        arguments = self.command()[2:]
        arguments.extend(["--wave", "W1"])

        completed = self.run_raw(arguments)

        self.assertEqual(completed.returncode, 2)
        self.assertIn("exactly once", completed.stderr.lower())

    def test_closed_cli_rejects_equals_form(self) -> None:
        arguments = self.command()[2:]
        index = arguments.index("--wave")
        arguments[index : index + 2] = ["--wave=W1"]

        completed = self.run_raw(arguments)

        self.assertEqual(completed.returncode, 2)
        self.assertIn("separate", completed.stderr.lower())

    def test_signing_configuration_is_rejected(self) -> None:
        self.git("config", "--local", "commit.gpgSign", "true")

        completed = self.run_prepare()

        self.assertEqual(completed.returncode, 3)
        self.assertIn("sign", completed.stderr.lower())

    def test_v2_git_reads_reject_replace_graft_shallow_and_missing_objects(
        self,
    ) -> None:
        self.git("replace", self.base_commit, self.original_commit)

        completed = self.run_prepare()

        self.assertEqual(completed.returncode, 3)
        self.assertIn("replace", completed.stderr.lower())

    def test_graft_file_is_rejected(self) -> None:
        grafts = self.root / ".git" / "info" / "grafts"
        grafts.write_text(
            f"{self.base_commit} {self.original_commit}\n",
            encoding="ascii",
        )

        completed = self.run_prepare()

        self.assertEqual(completed.returncode, 3)
        self.assertIn("graft", completed.stderr.lower())

    def test_shallow_repository_is_rejected(self) -> None:
        (self.root / ".git" / "shallow").write_text(
            f"{self.original_commit}\n",
            encoding="ascii",
        )

        completed = self.run_prepare()

        self.assertEqual(completed.returncode, 3)
        self.assertIn("shallow", completed.stderr.lower())

    def test_missing_candidate_object_fails_closed(self) -> None:
        completed = self.run_prepare(candidate_tree="0" * 40)

        self.assertEqual(completed.returncode, 4)
        self.assertIn("Git", completed.stderr)

    def test_candidate_preparation_rejects_unverified_or_wrong_family_predecessor(
        self,
    ) -> None:
        wrong = copy.deepcopy(self.previous_receipt)
        wrong["schema"] = "QinaoWaveAdmissionReceiptV1"
        wrong["terminalRoot"] = terminal_root(wrong)
        wrong_path = self.external / "wrong-family.json"
        self.write_external(wrong_path, wrong)

        completed = self.run_prepare(previous_receipt=wrong_path)

        self.assertEqual(completed.returncode, 3)
        self.assertIn("predecessor", completed.stderr.lower())

    def test_later_v2_target_and_base_inherit_prior_admission_terminal(self) -> None:
        w1_values, receipt_path = self.install_w1_and_stage_w2()

        completed = self.run_prepare(
            previous_receipt=receipt_path,
            wave="W2",
            wave_slice_id=W2_SLICE,
            sequence_ordinal=1,
            commit_message=W2_MESSAGE,
        )
        values = self.parse_success(completed)

        self.assertEqual(values[0], TARGET_REF)
        self.assertEqual(values[1], w1_values[3])
        self.assertEqual(values[2], self.git("rev-parse", w1_values[3] + "^{tree}"))

    def test_later_v2_rejects_invalid_predecessor_signature(self) -> None:
        _w1_values, receipt_path = self.install_w1_and_stage_w2()
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        receipt["signature"] = base64.b64encode(b"\x00" * 64).decode("ascii")
        self.write_external(receipt_path, receipt)

        completed = self.run_prepare(
            previous_receipt=receipt_path,
            wave="W2",
            wave_slice_id=W2_SLICE,
            sequence_ordinal=1,
            commit_message=W2_MESSAGE,
        )

        self.assertEqual(completed.returncode, 3)
        self.assertIn("signature", completed.stderr.lower())

    def test_tampered_migration_terminal_root_is_rejected(self) -> None:
        tampered = copy.deepcopy(self.previous_receipt)
        tampered["candidateTree"] = self.original_tree
        tampered_path = self.external / "tampered-migration.json"
        self.write_external(tampered_path, tampered)

        completed = self.run_prepare(previous_receipt=tampered_path)

        self.assertEqual(completed.returncode, 3)
        self.assertIn("terminalRoot", completed.stderr)

    def test_wrong_closed_slice_or_commit_message_is_rejected(self) -> None:
        wrong_slice = self.run_prepare(wave_slice_id="w1.not-in-registry")
        wrong_message = self.run_prepare(commit_message="almost the right message")

        self.assertEqual(wrong_slice.returncode, 3)
        self.assertEqual(wrong_message.returncode, 3)
        self.assertIn("schedule", wrong_slice.stderr.lower())
        self.assertIn("message", wrong_message.stderr.lower())


class PrepareGitExecutableBindingTests(unittest.TestCase):
    """Mutation-focused coverage for the executable namespace trust boundary."""

    @staticmethod
    def changed_status(
        value: os.stat_result,
        *,
        mode: int | None = None,
        uid: int | None = None,
        size: int | None = None,
    ) -> os.stat_result:
        fields = list(value)
        if mode is not None:
            fields[stat.ST_MODE] = mode
        if uid is not None:
            fields[stat.ST_UID] = uid
        if size is not None:
            fields[stat.ST_SIZE] = size
        return os.stat_result(fields)

    def bind_with_metadata(
        self,
        metadata_overrides: dict[Path, os.stat_result],
        access: object,
    ) -> prepare.BoundGitExecutable:
        original_lstat = Path.lstat

        def controlled_lstat(path: Path) -> os.stat_result:
            canonical = Path(path)
            return metadata_overrides.get(canonical, original_lstat(canonical))

        with (
            mock.patch.object(Path, "lstat", controlled_lstat),
            mock.patch.object(
                prepare.os,
                "access",
                side_effect=access,
            ),
        ):
            return prepare.bind_git_executable(TEST_GIT)

    @staticmethod
    def deny_writes_allow_execute(
        _path: object,
        mode: int,
        **_options: object,
    ) -> bool:
        return mode != os.W_OK

    def test_executable_owner_is_checked_independently(self) -> None:
        original = TEST_GIT.lstat()
        metadata = {
            TEST_GIT: self.changed_status(original, uid=max(1, original.st_uid + 1))
        }

        with self.assertRaisesRegex(prepare.PreparationError, "root-owned"):
            self.bind_with_metadata(metadata, self.deny_writes_allow_execute)

    def test_parent_owner_is_checked_independently(self) -> None:
        parent = TEST_GIT.parent
        original = parent.lstat()
        metadata = {
            parent: self.changed_status(original, uid=max(1, original.st_uid + 1))
        }

        with self.assertRaisesRegex(prepare.PreparationError, "root-owned"):
            self.bind_with_metadata(metadata, self.deny_writes_allow_execute)

    def test_current_security_subject_writability_is_checked_independently(
        self,
    ) -> None:
        def writable_executable(
            path: object,
            mode: int,
            **_options: object,
        ) -> bool:
            return mode == os.X_OK or (mode == os.W_OK and Path(path) == TEST_GIT)

        with self.assertRaisesRegex(prepare.PreparationError, "non-writable"):
            self.bind_with_metadata({}, writable_executable)

    def test_writable_ancestor_mode_is_checked_independently(self) -> None:
        parent = TEST_GIT.parent
        original = parent.lstat()
        metadata = {
            parent: self.changed_status(
                original,
                mode=original.st_mode | stat.S_IWGRP,
            )
        }

        with self.assertRaisesRegex(prepare.PreparationError, "non-writable"):
            self.bind_with_metadata(metadata, self.deny_writes_allow_execute)

    def test_write_access_uses_effective_security_identity(self) -> None:
        observed: list[tuple[int, dict[str, object]]] = []

        def record_access(
            _path: object,
            mode: int,
            **options: object,
        ) -> bool:
            observed.append((mode, options))
            return mode != os.W_OK

        bound = self.bind_with_metadata({}, record_access)
        self.addCleanup(bound.close)

        write_checks = [options for mode, options in observed if mode == os.W_OK]
        self.assertEqual(len(write_checks), len((TEST_GIT, *TEST_GIT.parents)))
        self.assertTrue(write_checks)
        self.assertTrue(
            all(options == {"effective_ids": True} for options in write_checks)
        )

    def test_missing_effective_identity_access_support_fails_closed(self) -> None:
        def unsupported_effective_identity(
            _path: object,
            mode: int,
            **options: object,
        ) -> bool:
            if mode == os.W_OK and options.get("effective_ids") is True:
                raise TypeError("effective_ids is unavailable")
            return mode != os.W_OK

        with self.assertRaisesRegex(
            prepare.PreparationError,
            "security subject.*inspect|effective identity",
        ):
            self.bind_with_metadata({}, unsupported_effective_identity)

    def test_stable_open_detects_descriptor_identity_drift(self) -> None:
        original_fstat = prepare.os.fstat

        def drifted_fstat(descriptor: int) -> os.stat_result:
            value = original_fstat(descriptor)
            return self.changed_status(value, size=value.st_size + 1)

        with mock.patch.object(prepare.os, "fstat", side_effect=drifted_fstat):
            with self.assertRaisesRegex(
                prepare.PreparationError,
                "path/descriptor binding mismatch",
            ):
                prepare.bind_git_executable(TEST_GIT)


if __name__ == "__main__":
    unittest.main()
